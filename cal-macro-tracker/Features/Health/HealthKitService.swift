import Foundation
import HealthKit
import Observation
import SwiftData

enum HealthNutritionAuthorization {
    static func isAuthorized(_ status: HKAuthorizationStatus) -> Bool {
        status == .sharingAuthorized
    }

    static func authorizedIdentifiers(
        statuses: [HKQuantityTypeIdentifier: HKAuthorizationStatus]
    ) -> Set<HKQuantityTypeIdentifier> {
        Set(
            statuses.compactMap { identifier, status in
                isAuthorized(status) ? identifier : nil
            })
    }
}

struct HealthQueryLifecycle {
    private(set) var generation = 0
    private(set) var isActive = false

    mutating func start() -> Int {
        generation += 1
        isActive = true
        return generation
    }

    mutating func stop() {
        generation += 1
        isActive = false
    }

    func accepts(_ candidate: Int) -> Bool {
        isActive && candidate == generation
    }
}

@MainActor
@Observable
final class HealthKitService {
    private(set) var statusText =
        HKHealthStore.isHealthDataAvailable() ? "Apple Health is available." : "Apple Health is not available on this device."
    private let store = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    private var isObservingWeight = false
    private var weightLifecycle = HealthQueryLifecycle()
    private var weightImportQuery: HKAnchoredObjectQuery?
    private var weightImportContinuation: CheckedContinuation<Void, Never>?
    private var pendingWeightImport = false
    private var weightContainer: ModelContainer?
    private var backfillTask: Task<Void, Never>?
    private var backfillGeneration = 0
    private(set) var isBackfilling = false

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization(readWeight: Bool = false) async throws {
        guard isAvailable else { return }
        let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass)
        try await store.requestAuthorization(
            toShare: nutritionTypes,
            read: readWeight ? Set(bodyMass.map { [$0] } ?? []) : []
        )
        statusText = "Health access updated. Manage permissions in the Health app."
    }

    func writeNutrition(for entry: LogEntry) async {
        guard isAvailable else { return }
        let values: [(HKQuantityTypeIdentifier, Double?, HKUnit)] = [
            (.dietaryEnergyConsumed, entry.caloriesConsumed, .kilocalorie()),
            (.dietaryProtein, entry.proteinConsumed, .gram()),
            (.dietaryCarbohydrates, entry.carbsConsumed, .gram()),
            (.dietaryFatTotal, entry.fatConsumed, .gram()),
            (.dietaryFatSaturated, entry.saturatedFatConsumed, .gram()),
            (.dietaryFiber, entry.fiberConsumed, .gram()),
            (.dietarySugar, entry.sugarsConsumed, .gram()),
            (.dietarySodium, entry.sodiumConsumed, .gramUnit(with: .milli)),
            (.dietaryCholesterol, entry.cholesterolConsumed, .gramUnit(with: .milli))
        ]
        let authorizationStatuses = Dictionary(
            uniqueKeysWithValues: values.compactMap { identifier, _, _ in
                HKObjectType.quantityType(forIdentifier: identifier).map { (identifier, store.authorizationStatus(for: $0)) }
            })
        let authorizedIdentifiers = HealthNutritionAuthorization.authorizedIdentifiers(statuses: authorizationStatuses)
        let hasUnauthorizedTypes = authorizedIdentifiers.count < values.count
        var samples: [HKQuantitySample] = []
        var deletionFailed = false
        for (identifier, amount, unit) in values {
            guard authorizedIdentifiers.contains(identifier) else { continue }
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { continue }
            let syncIdentifier = "\(entry.id.uuidString).\(identifier.rawValue)"
            guard let amount, amount.isFinite else {
                let predicate = HKQuery.predicateForObjects(
                    withMetadataKey: HKMetadataKeySyncIdentifier, operatorType: .equalTo, value: syncIdentifier)
                do {
                    try await store.deleteObjects(of: type, predicate: predicate)
                } catch {
                    deletionFailed = true
                }
                continue
            }
            let metadata: [String: Any] = [
                HKMetadataKeySyncIdentifier: syncIdentifier,
                HKMetadataKeySyncVersion: entry.healthSyncVersion
            ]
            samples.append(
                HKQuantitySample(
                    type: type, quantity: HKQuantity(unit: unit, doubleValue: amount), start: entry.dateLogged, end: entry.dateLogged,
                    metadata: metadata))
        }
        guard !samples.isEmpty else {
            statusText =
                deletionFailed
                ? "Could not update nutrition in Apple Health."
                : hasUnauthorizedTypes
                    ? "No enabled Health nutrition categories to update. Review access in the Health app."
                    : "Nutrition updated in Apple Health."
            return
        }
        do {
            try await store.save(samples)
            statusText =
                if deletionFailed {
                    "Some nutrition could not be updated in Apple Health."
                } else if hasUnauthorizedTypes {
                    "Nutrition saved for enabled categories. Enable others in the Health app to sync all values."
                } else {
                    "Nutrition saved to Apple Health."
                }
        } catch {
            statusText = "Could not save nutrition to Apple Health."
        }
    }

    func deleteNutrition(for entryID: UUID) async {
        var deletionFailed = false
        var skippedUnauthorizedType = false
        for type in nutritionTypes {
            guard HealthNutritionAuthorization.isAuthorized(store.authorizationStatus(for: type)) else {
                skippedUnauthorizedType = true
                continue
            }
            let syncIdentifier = "\(entryID.uuidString).\(type.identifier.rawValue)"
            let predicate = HKQuery.predicateForObjects(
                withMetadataKey: HKMetadataKeySyncIdentifier, operatorType: .equalTo, value: syncIdentifier)
            do {
                try await store.deleteObjects(of: type, predicate: predicate)
            } catch {
                deletionFailed = true
            }
        }
        statusText =
            if deletionFailed {
                "Some nutrition could not be removed from Apple Health."
            } else if skippedUnauthorizedType {
                "Nutrition was removed from enabled Health categories. Review other permissions in the Health app."
            } else {
                "Nutrition removed from Apple Health."
            }
    }

    func backfill(days: Int, container: ModelContainer) async {
        guard isAvailable, days > 0 else { return }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let entries = (try? container.mainContext.fetch(FetchDescriptor<LogEntry>())) ?? []
        for entry in entries where entry.dateLogged >= start {
            if Task.isCancelled { return }
            await writeNutrition(for: entry)
        }
    }

    func startBackfill(days: Int, container: ModelContainer) {
        guard !isBackfilling else { return }
        backfillGeneration += 1
        let generation = backfillGeneration
        isBackfilling = true
        backfillTask = Task { [weak self] in
            await self?.backfill(days: days, container: container)
            guard let self, self.backfillGeneration == generation else { return }
            self.isBackfilling = false
            self.backfillTask = nil
        }
    }

    func cancelBackfill() {
        backfillGeneration += 1
        backfillTask?.cancel()
        backfillTask = nil
        isBackfilling = false
    }

    func startWeightObservation(container: ModelContainer) {
        guard isAvailable, observerQuery == nil,
            let type = HKObjectType.quantityType(forIdentifier: .bodyMass)
        else { return }
        isObservingWeight = true
        weightContainer = container
        let generation = weightLifecycle.start()
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, _ in
            Task { @MainActor in
                guard let self, self.weightLifecycle.accepts(generation) else {
                    completion()
                    return
                }
                await self.importWeights(into: container, type: type)
                completion()
            }
        }
        observerQuery = query
        store.execute(query)
        Task { await importWeights(into: container, type: type) }
    }

    func stopWeightObservation() {
        isObservingWeight = false
        weightLifecycle.stop()
        pendingWeightImport = false
        weightContainer = nil
        if let observerQuery {
            store.stop(observerQuery)
            self.observerQuery = nil
        }
        if let weightImportQuery {
            store.stop(weightImportQuery)
            self.weightImportQuery = nil
            let continuation = weightImportContinuation
            weightImportContinuation = nil
            continuation?.resume()
        }
    }

    private func importWeights(into container: ModelContainer, type: HKQuantityType) async {
        guard
            isObservingWeight,
            weightLifecycle.isActive,
            UserDefaults.standard.bool(forKey: AppStorageKeys.healthWeightReadEnabled)
        else { return }
        guard weightImportQuery == nil else {
            pendingWeightImport = true
            return
        }
        let generation = weightLifecycle.generation
        let anchor = UserDefaults.standard.data(forKey: "healthWeightAnchor")
            .flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }
        let importStartDate = Calendar.current.date(byAdding: .day, value: -365, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: importStartDate, end: nil)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            weightImportContinuation = continuation
            let query = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: anchor, limit: HKObjectQueryNoLimit) {
                completedQuery, samples, deletedObjects, newAnchor, error in
                guard error == nil else {
                    Task { @MainActor in
                        guard self.weightImportQuery === completedQuery else { return }
                        self.statusText = "Could not import weight from Apple Health."
                        self.finishWeightImport(continuation: continuation)
                    }
                    return
                }
                let imported =
                    (samples as? [HKQuantitySample])?.map {
                        HealthWeightSample(
                            uuid: $0.uuid.uuidString, date: $0.endDate, kilograms: $0.quantity.doubleValue(for: .gramUnit(with: .kilo)))
                    } ?? []
                let deletedUUIDs = (deletedObjects ?? []).map { $0.uuid.uuidString }
                Task { @MainActor in
                    guard self.weightImportQuery === completedQuery else { return }
                    if self.weightLifecycle.accepts(generation),
                        UserDefaults.standard.bool(forKey: AppStorageKeys.healthWeightReadEnabled)
                    {
                        do {
                            try WeightRepository(modelContext: container.mainContext)
                                .applyHealthChanges(imported, deletedUUIDs: deletedUUIDs)
                            if let newAnchor,
                                let data = try? NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true)
                            {
                                UserDefaults.standard.set(data, forKey: "healthWeightAnchor")
                            }
                        } catch {
                            self.statusText = "Could not import weight from Apple Health."
                        }
                    }
                    self.finishWeightImport(continuation: continuation)
                }
            }
            weightImportQuery = query
            store.execute(query)
        }
    }

    private func finishWeightImport(continuation: CheckedContinuation<Void, Never>) {
        weightImportQuery = nil
        weightImportContinuation = nil
        continuation.resume()
        guard pendingWeightImport, isObservingWeight, weightLifecycle.isActive else { return }
        pendingWeightImport = false
        guard
            let container = weightContainer,
            let type = HKObjectType.quantityType(forIdentifier: .bodyMass)
        else { return }
        Task { await importWeights(into: container, type: type) }
    }

    private var nutritionTypes: Set<HKSampleType> {
        Set(
            [
                HKQuantityTypeIdentifier.dietaryEnergyConsumed,
                .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal, .dietaryFatSaturated,
                .dietaryFiber, .dietarySugar, .dietarySodium, .dietaryCholesterol
            ].compactMap(HKObjectType.quantityType(forIdentifier:)))
    }
}
