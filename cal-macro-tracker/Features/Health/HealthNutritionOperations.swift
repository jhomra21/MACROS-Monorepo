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

    static func deleteSamples(
        for entryID: UUID,
        authorizedIdentifiers: Set<String>,
        delete: (String, String) async throws -> Void
    ) async -> String? {
        var firstError: String?
        for (nutrientIdentifier, syncIdentifier) in zip(nutrientIdentifiers, deletionIdentifiers(for: entryID))
        where authorizedIdentifiers.contains(nutrientIdentifier) {
            do {
                try await delete(nutrientIdentifier, syncIdentifier)
            } catch {
                firstError = firstError ?? error.localizedDescription
            }
        }
        return firstError
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
    case failure(String)
    case superseded
}

struct HealthNutritionBackfillResult: Equatable {
    var written = 0
    var skipped = 0
    var failed = 0
    var firstError: String?
    private var syncedDays = Set<Date>()

    var syncedDayCount: Int { syncedDays.count }

    mutating func record(_ result: HealthNutritionStoreResult, on date: Date) {
        switch result {
        case .success:
            written += 1
            syncedDays.insert(Calendar.current.startOfDay(for: date))
        case .partial:
            written += 1
            syncedDays.insert(Calendar.current.startOfDay(for: date))
        case .noAuthorizedTypes, .superseded:
            skipped += 1
        case let .failure(error):
            failed += 1
            firstError = firstError ?? error
        }
    }
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
        let backfillBatchID: UUID?
        let backfillIndex: Int?
    }

    private struct BackfillBatch {
        var results: [HealthNutritionStoreResult?]
        let continuation: CheckedContinuation<[HealthNutritionStoreResult], Never>
    }

    private let store: any HealthNutritionStore
    private let didEnqueue: (@MainActor (HealthNutritionOperation) -> Void)?
    private var pending: [PendingOperation] = []
    private var isDraining = false
    private var backfillBatches: [UUID: BackfillBatch] = [:]

    init(
        store: any HealthNutritionStore,
        didEnqueue: (@MainActor (HealthNutritionOperation) -> Void)? = nil
    ) {
        self.store = store
        self.didEnqueue = didEnqueue
    }

    func enqueue(_ operation: HealthNutritionOperation) async -> HealthNutritionStoreResult {
        await withCheckedContinuation { continuation in
            append(
                PendingOperation(
                    operation: operation,
                    source: .user,
                    continuation: continuation,
                    backfillBatchID: nil,
                    backfillIndex: nil
                ))
            didEnqueue?(operation)
            startDrainingIfNeeded()
        }
    }

    func enqueueBackfill(_ operations: [HealthNutritionOperation]) async -> [HealthNutritionStoreResult] {
        guard !operations.isEmpty else { return [] }
        let batchID = UUID()
        return await withCheckedContinuation { continuation in
            backfillBatches[batchID] = BackfillBatch(
                results: Array(repeating: nil, count: operations.count),
                continuation: continuation
            )
            for (index, operation) in operations.enumerated() {
                append(
                    PendingOperation(
                        operation: operation,
                        source: .backfill,
                        continuation: nil,
                        backfillBatchID: batchID,
                        backfillIndex: index
                    ))
                didEnqueue?(operation)
            }
            startDrainingIfNeeded()
        }
    }

    func cancelPendingBackfill() {
        let cancelled = pending.filter { $0.source == .backfill }
        pending.removeAll { $0.source == .backfill }
        cancelled.forEach { complete($0, with: .superseded) }
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
            superseded.forEach { complete($0, with: .superseded) }
        }
        pending.append(pendingOperation)
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
            complete(pendingOperation, with: result)
        }
        isDraining = false
    }

    private func complete(_ pendingOperation: PendingOperation, with result: HealthNutritionStoreResult) {
        if let continuation = pendingOperation.continuation {
            continuation.resume(returning: result)
            return
        }
        guard let batchID = pendingOperation.backfillBatchID,
            let index = pendingOperation.backfillIndex,
            var batch = backfillBatches[batchID]
        else { return }
        batch.results[index] = result
        guard batch.results.allSatisfy({ $0 != nil }) else {
            backfillBatches[batchID] = batch
            return
        }
        backfillBatches[batchID] = nil
        batch.continuation.resume(returning: batch.results.compactMap { $0 })
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
        var deletionError: String?

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
                    deletionError = deletionError ?? error.localizedDescription
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
                return .failure(error.localizedDescription)
            }
        }
        if let deletionError { return .failure(deletionError) }
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
        let error = await HealthNutritionSnapshot.deleteSamples(
            for: entryID,
            authorizedIdentifiers: Set(authorized.map(\.rawValue))
        ) { nutrientIdentifier, syncIdentifier in
            guard
                let type = HKObjectType.quantityType(
                    forIdentifier: HKQuantityTypeIdentifier(rawValue: nutrientIdentifier))
            else {
                throw HealthNutritionDeletionError.missingQuantityType
            }
            try await store.deleteObjects(of: type, predicate: Self.predicate(for: syncIdentifier))
        }
        if let error { return .failure(error) }
        return authorized.count < Self.definitions.count ? .partial : .success
    }

    private static func predicate(for identifier: String) -> NSPredicate {
        HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeySyncIdentifier,
            operatorType: .equalTo,
            value: identifier
        )
    }

    private enum HealthNutritionDeletionError: LocalizedError {
        case missingQuantityType

        var errorDescription: String? {
            "A Health nutrition category is unavailable."
        }
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
