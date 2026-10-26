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
    private let store: HKHealthStore
    private let nutritionOperations: HealthNutritionOperationQueue
    private let isAvailableOverride: Bool?
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
    private(set) var backfillErrorMessage: String?

    init(
        nutritionStore: (any HealthNutritionStore)? = nil,
        isAvailableOverride: Bool? = nil,
        didEnqueueNutritionOperation: (@MainActor (HealthNutritionOperation) -> Void)? = nil
    ) {
        let store = HKHealthStore()
        self.store = store
        self.isAvailableOverride = isAvailableOverride
        if let nutritionStore {
            nutritionOperations = HealthNutritionOperationQueue(
                store: nutritionStore,
                didEnqueue: didEnqueueNutritionOperation
            )
        } else {
            nutritionOperations = HealthNutritionOperationQueue(
                store: HealthKitNutritionStore(store: store),
                didEnqueue: didEnqueueNutritionOperation
            )
        }
    }

    var isAvailable: Bool { isAvailableOverride ?? HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization(readWeight: Bool = false) async throws {
        guard isAvailable else { return }
        let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass)
        try await store.requestAuthorization(
            toShare: Self.nutritionTypes,
            read: readWeight ? Set(bodyMass.map { [$0] } ?? []) : []
        )
        statusText = "Health access updated. Manage permissions in the Health app."
    }

    func writeNutrition(for entry: LogEntry) async {
        guard isAvailable else { return }
        let snapshot = HealthNutritionSnapshot(entry: entry)
        let result = await enqueueNutritionOperation(.write(snapshot))
        switch result {
        case .success:
            statusText = "Nutrition saved to Apple Health."
        case .partial:
            statusText = "Nutrition saved for enabled categories. Enable others in the Health app to sync all values."
        case .noAuthorizedTypes:
            statusText = "No enabled Health nutrition categories to update. Review access in the Health app."
        case let .failure(error):
            statusText = error
        case .superseded:
            break
        }
    }

    func deleteNutrition(for entryID: UUID) async {
        let result = await enqueueNutritionOperation(.delete(entryID: entryID))
        switch result {
        case .success:
            statusText = "Nutrition removed from Apple Health."
        case .partial:
            statusText = "Nutrition was removed from enabled Health categories. Review other permissions in the Health app."
        case .noAuthorizedTypes:
            statusText = "No Health nutrition categories are enabled. Review access in the Health app."
        case let .failure(error):
            statusText = error
        case .superseded:
            break
        }
    }

    func enqueueNutritionOperation(_ operation: HealthNutritionOperation) async -> HealthNutritionStoreResult {
        await nutritionOperations.enqueue(operation)
    }

    func backfill(days: Int, container: ModelContainer) async -> HealthNutritionBackfillResult {
        guard isAvailable, days > 0 else { return HealthNutritionBackfillResult() }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let entries = (try? container.mainContext.fetch(FetchDescriptor<LogEntry>())) ?? []
        let snapshots =
            entries
            .filter { $0.dateLogged >= start }
            .map(HealthNutritionSnapshot.init(entry:))
        if Task.isCancelled { return HealthNutritionBackfillResult() }
        let results = await nutritionOperations.enqueueBackfill(snapshots.map(HealthNutritionOperation.write))
        if Task.isCancelled { return HealthNutritionBackfillResult() }
        return Self.backfillResult(for: results, snapshots: snapshots)
    }

    func startBackfill(days: Int, container: ModelContainer) {
        startBackfill { [weak self] in
            guard let self else { return HealthNutritionBackfillResult() }
            return await self.backfill(days: days, container: container)
        }
    }

    func startBackfill(snapshots: [HealthNutritionSnapshot]) {
        startBackfill { [weak self] in
            guard let self, self.isAvailable else { return HealthNutritionBackfillResult() }
            return await self.backfill(snapshots: snapshots)
        }
    }

    private func startBackfill(operation: @escaping @MainActor () async -> HealthNutritionBackfillResult) {
        guard !isBackfilling else { return }
        backfillGeneration += 1
        let generation = backfillGeneration
        isBackfilling = true
        backfillErrorMessage = nil
        backfillTask = Task { [weak self] in
            let result = await operation()
            guard let self, self.backfillGeneration == generation else { return }
            if result.failed > 0 {
                self.statusText =
                    "Last sync failed: \(result.failedDayCount) of \(result.attemptedDayCount) days"
                self.backfillErrorMessage = result.firstError ?? "Could not sync nutrition to Apple Health."
            } else {
                self.statusText = "Synced \(result.syncedDayCount) days"
            }
            self.isBackfilling = false
            self.backfillTask = nil
        }
    }

    func backfill(snapshots: [HealthNutritionSnapshot]) async -> HealthNutritionBackfillResult {
        guard !Task.isCancelled else { return HealthNutritionBackfillResult() }
        let results = await nutritionOperations.enqueueBackfill(snapshots.map(HealthNutritionOperation.write))
        guard !Task.isCancelled else { return HealthNutritionBackfillResult() }
        return Self.backfillResult(for: results, snapshots: snapshots)
    }

    private static func backfillResult(
        for results: [HealthNutritionStoreResult],
        snapshots: [HealthNutritionSnapshot]
    ) -> HealthNutritionBackfillResult {
        zip(results, snapshots).reduce(into: HealthNutritionBackfillResult()) { summary, pair in
            summary.record(pair.0, on: pair.1.startDate)
        }
    }

    func cancelBackfill() async {
        backfillGeneration += 1
        let cancellationGeneration = backfillGeneration
        guard let task = backfillTask else {
            nutritionOperations.cancelPendingBackfill()
            isBackfilling = false
            return
        }
        task.cancel()
        nutritionOperations.cancelPendingBackfill()
        await task.value
        guard backfillGeneration == cancellationGeneration else { return }
        backfillTask = nil
        isBackfilling = false
    }

    func clearBackfillError() {
        backfillErrorMessage = nil
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

    func restartWeightObservation(container: ModelContainer) {
        stopWeightObservation()
        startWeightObservation(container: container)
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

    private static var nutritionTypes: Set<HKSampleType> {
        Set(
            HealthNutritionSnapshot.nutrientIdentifiers.compactMap {
                HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: $0))
            })
    }

}
