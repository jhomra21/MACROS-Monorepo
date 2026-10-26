import Foundation
import HealthKit

struct HealthNutritionValue: Equatable {
    let identifier: String
    let amount: Double?
}

struct HealthNutritionSnapshot: Equatable {
    static let nutrientIdentifiers: [String] = [
        HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue,
        HKQuantityTypeIdentifier.dietaryProtein.rawValue,
        HKQuantityTypeIdentifier.dietaryCarbohydrates.rawValue,
        HKQuantityTypeIdentifier.dietaryFatTotal.rawValue,
        HKQuantityTypeIdentifier.dietaryFatSaturated.rawValue,
        HKQuantityTypeIdentifier.dietaryFiber.rawValue,
        HKQuantityTypeIdentifier.dietarySugar.rawValue,
        HKQuantityTypeIdentifier.dietarySodium.rawValue,
        HKQuantityTypeIdentifier.dietaryCholesterol.rawValue
    ]

    static func deletionIdentifiers(for entryID: UUID) -> [String] {
        nutrientIdentifiers.map { "\(entryID.uuidString).\($0)" }
    }

    let entryID: UUID
    let nutrients: [HealthNutritionValue]
    let startDate: Date
    let endDate: Date
    let syncVersion: Int

    init(entry: LogEntry) {
        entryID = entry.id
        nutrients = [
            HealthNutritionValue(identifier: HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue, amount: entry.caloriesConsumed),
            HealthNutritionValue(identifier: HKQuantityTypeIdentifier.dietaryProtein.rawValue, amount: entry.proteinConsumed),
            HealthNutritionValue(
                identifier: HKQuantityTypeIdentifier.dietaryCarbohydrates.rawValue, amount: entry.carbsConsumed),
            HealthNutritionValue(identifier: HKQuantityTypeIdentifier.dietaryFatTotal.rawValue, amount: entry.fatConsumed),
            HealthNutritionValue(
                identifier: HKQuantityTypeIdentifier.dietaryFatSaturated.rawValue, amount: entry.saturatedFatConsumed),
            HealthNutritionValue(identifier: HKQuantityTypeIdentifier.dietaryFiber.rawValue, amount: entry.fiberConsumed),
            HealthNutritionValue(identifier: HKQuantityTypeIdentifier.dietarySugar.rawValue, amount: entry.sugarsConsumed),
            HealthNutritionValue(identifier: HKQuantityTypeIdentifier.dietarySodium.rawValue, amount: entry.sodiumConsumed),
            HealthNutritionValue(
                identifier: HKQuantityTypeIdentifier.dietaryCholesterol.rawValue, amount: entry.cholesterolConsumed)
        ]
        startDate = entry.dateLogged
        endDate = entry.dateLogged
        syncVersion = entry.healthSyncVersion
    }
}

enum HealthNutritionOperation: Equatable {
    case write(HealthNutritionSnapshot)
    case delete(entryID: UUID)

    var entryID: UUID {
        switch self {
        case let .write(snapshot): snapshot.entryID
        case let .delete(entryID): entryID
        }
    }
}

enum HealthNutritionStoreResult: Equatable {
    case success
    case partial
    case noAuthorizedTypes
    case failure
    case superseded
}

@MainActor
protocol HealthNutritionStore: AnyObject {
    func apply(_ operation: HealthNutritionOperation) async -> HealthNutritionStoreResult
}

@MainActor
final class HealthNutritionOperationQueue {
    private enum Source: Equatable {
        case user
        case backfill
    }

    private struct PendingOperation {
        let operation: HealthNutritionOperation
        let source: Source
        let continuation: CheckedContinuation<HealthNutritionStoreResult, Never>?
    }

    private let store: any HealthNutritionStore
    private var pending: [PendingOperation] = []
    private var isDraining = false
    private var idleContinuations: [CheckedContinuation<Void, Never>] = []

    init(store: any HealthNutritionStore) {
        self.store = store
    }

    func enqueue(_ operation: HealthNutritionOperation) async -> HealthNutritionStoreResult {
        await withCheckedContinuation { continuation in
            append(PendingOperation(operation: operation, source: .user, continuation: continuation))
            startDrainingIfNeeded()
        }
    }

    func enqueueBackfill(_ operations: [HealthNutritionOperation]) async {
        for operation in operations {
            append(PendingOperation(operation: operation, source: .backfill, continuation: nil))
        }
        startDrainingIfNeeded()
        await waitUntilDrained()
    }

    func cancelPendingBackfill() {
        pending.removeAll { $0.source == .backfill }
    }

    private func append(_ pendingOperation: PendingOperation) {
        if case let .delete(entryID) = pendingOperation.operation {
            let superseded = pending.filter {
                if case .write = $0.operation { return $0.operation.entryID == entryID }
                return false
            }
            pending.removeAll {
                if case .write = $0.operation { return $0.operation.entryID == entryID }
                return false
            }
            superseded.forEach { $0.continuation?.resume(returning: .superseded) }
        }
        pending.append(pendingOperation)
    }

    private func waitUntilDrained() async {
        guard isDraining else { return }
        await withCheckedContinuation { continuation in
            idleContinuations.append(continuation)
        }
    }

    private func startDrainingIfNeeded() {
        guard !isDraining else { return }
        isDraining = true
        Task { await drain() }
    }

    private func drain() async {
        while !pending.isEmpty {
            let pendingOperation = pending.removeFirst()
            let result = await store.apply(pendingOperation.operation)
            pendingOperation.continuation?.resume(returning: result)
        }
        isDraining = false
        let continuations = idleContinuations
        idleContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }
}

@MainActor
final class HealthKitNutritionStore: HealthNutritionStore {
    private struct NutrientDefinition {
        let identifier: HKQuantityTypeIdentifier
        let unit: HKUnit
    }

    private let store: HKHealthStore

    init(store: HKHealthStore) {
        self.store = store
    }

    func apply(_ operation: HealthNutritionOperation) async -> HealthNutritionStoreResult {
        switch operation {
        case let .write(snapshot):
            await write(snapshot)
        case let .delete(entryID):
            await delete(entryID)
        }
    }

    private func write(_ snapshot: HealthNutritionSnapshot) async -> HealthNutritionStoreResult {
        let definitions = Self.definitions
        let authorizationStatuses = Dictionary(
            uniqueKeysWithValues: definitions.compactMap { definition in
                HKObjectType.quantityType(forIdentifier: definition.identifier).map {
                    (definition.identifier, store.authorizationStatus(for: $0))
                }
            })
        let authorized = HealthNutritionAuthorization.authorizedIdentifiers(statuses: authorizationStatuses)
        let valuesByIdentifier = Dictionary(uniqueKeysWithValues: snapshot.nutrients.map { ($0.identifier, $0.amount) })
        var samples: [HKQuantitySample] = []
        var deletionFailed = false

        if authorized.isEmpty { return .noAuthorizedTypes }

        for definition in definitions {
            guard authorized.contains(definition.identifier),
                let type = HKObjectType.quantityType(forIdentifier: definition.identifier)
            else { continue }

            let syncIdentifier = "\(snapshot.entryID.uuidString).\(definition.identifier.rawValue)"
            guard let amount = valuesByIdentifier[definition.identifier.rawValue] ?? nil,
                amount.isFinite
            else {
                let predicate = Self.predicate(for: syncIdentifier)
                do {
                    try await store.deleteObjects(of: type, predicate: predicate)
                } catch {
                    deletionFailed = true
                }
                continue
            }

            let metadata: [String: Any] = [
                HKMetadataKeySyncIdentifier: syncIdentifier,
                HKMetadataKeySyncVersion: snapshot.syncVersion
            ]
            samples.append(
                HKQuantitySample(
                    type: type,
                    quantity: HKQuantity(unit: definition.unit, doubleValue: amount),
                    start: snapshot.startDate,
                    end: snapshot.endDate,
                    metadata: metadata
                )
            )
        }

        if !samples.isEmpty {
            do {
                try await store.save(samples)
            } catch {
                return .failure
            }
        }
        if deletionFailed { return .failure }
        return authorized.count < definitions.count ? .partial : .success
    }

    private func delete(_ entryID: UUID) async -> HealthNutritionStoreResult {
        let authorizationStatuses = Dictionary(
            uniqueKeysWithValues: Self.definitions.compactMap { definition in
                HKObjectType.quantityType(forIdentifier: definition.identifier).map {
                    (definition.identifier, store.authorizationStatus(for: $0))
                }
            })
        let authorized = HealthNutritionAuthorization.authorizedIdentifiers(statuses: authorizationStatuses)
        if authorized.isEmpty { return .noAuthorizedTypes }
        var failed = false
        let identifiers = HealthNutritionSnapshot.deletionIdentifiers(for: entryID)
        for (definition, identifier) in zip(Self.definitions, identifiers) {
            guard authorized.contains(definition.identifier),
                let type = HKObjectType.quantityType(forIdentifier: definition.identifier)
            else { continue }
            do {
                try await store.deleteObjects(of: type, predicate: Self.predicate(for: identifier))
            } catch {
                failed = true
            }
        }
        if failed { return .failure }
        return authorized.count < Self.definitions.count ? .partial : .success
    }

    private static func predicate(for identifier: String) -> NSPredicate {
        HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeySyncIdentifier,
            operatorType: .equalTo,
            value: identifier
        )
    }

    private static let definitions: [NutrientDefinition] = [
        NutrientDefinition(identifier: .dietaryEnergyConsumed, unit: .kilocalorie()),
        NutrientDefinition(identifier: .dietaryProtein, unit: .gram()),
        NutrientDefinition(identifier: .dietaryCarbohydrates, unit: .gram()),
        NutrientDefinition(identifier: .dietaryFatTotal, unit: .gram()),
        NutrientDefinition(identifier: .dietaryFatSaturated, unit: .gram()),
        NutrientDefinition(identifier: .dietaryFiber, unit: .gram()),
        NutrientDefinition(identifier: .dietarySugar, unit: .gram()),
        NutrientDefinition(identifier: .dietarySodium, unit: .gramUnit(with: .milli)),
        NutrientDefinition(identifier: .dietaryCholesterol, unit: .gramUnit(with: .milli))
    ]
}
