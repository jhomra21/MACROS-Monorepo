import HealthKit
import XCTest
@testable import cal_macro_tracker

final class HealthSynchronizationTests: XCTestCase {
    @MainActor
    func testNutritionWritesIncludeOnlyAuthorizedTypes() {
        let authorized = HealthNutritionAuthorization.authorizedIdentifiers(
            statuses: [
                .dietaryEnergyConsumed: .sharingAuthorized,
                .dietaryProtein: .sharingDenied,
                .dietaryCarbohydrates: .sharingAuthorized,
                .dietaryFatTotal: .notDetermined
            ])

        XCTAssertEqual(authorized, [.dietaryEnergyConsumed, .dietaryCarbohydrates])
    }

    @MainActor
    func testHealthImportGenerationRejectsStoppedAndOlderCallbacks() {
        var lifecycle = HealthQueryLifecycle()
        let first = lifecycle.start()
        XCTAssertTrue(lifecycle.accepts(first))

        lifecycle.stop()
        XCTAssertFalse(lifecycle.accepts(first))

        let second = lifecycle.start()
        XCTAssertNotEqual(first, second)
        XCTAssertFalse(lifecycle.accepts(first))
        XCTAssertTrue(lifecycle.accepts(second))
    }

    @MainActor
    func testEditDuringWriteUsesCapturedSnapshotRevision() async {
        let store = RecordingHealthNutritionStore()
        store.suspendNextApply = true
        let service = HealthKitService(
            nutritionStore: store,
            isAvailableOverride: true,
            didEnqueueNutritionOperation: { store.recordEnqueued($0) }
        )
        let entry = makeEntry(version: 4, calories: 100)
        let oldSnapshot = HealthNutritionSnapshot(entry: entry)

        let oldWrite = Task { await service.writeNutrition(for: entry) }
        await store.waitUntilSuspended()
        entry.healthSyncVersion = 5
        entry.caloriesConsumed = 150
        let newSnapshot = HealthNutritionSnapshot(entry: entry)
        let newWrite = Task { await service.writeNutrition(for: entry) }
        store.resumeSuspendedApply()
        await oldWrite.value
        await newWrite.value

        XCTAssertEqual(store.operations, [.write(oldSnapshot), .write(newSnapshot)])
    }

    @MainActor
    func testDeleteAfterWriteNeverResurrectsNutrition() async {
        let store = RecordingHealthNutritionStore()
        store.suspendNextApply = true
        let service = HealthKitService(
            nutritionStore: store,
            isAvailableOverride: true,
            didEnqueueNutritionOperation: { store.recordEnqueued($0) }
        )
        let entry = makeEntry(version: 1, calories: 100)

        let write = Task { await service.writeNutrition(for: entry) }
        await store.waitUntilSuspended()
        let delete = Task { await service.deleteNutrition(for: entry.id) }
        await store.waitUntilEnqueued(count: 2)
        XCTAssertEqual(store.enqueuedOperations.last, .delete(entryID: entry.id))
        store.resumeSuspendedApply()
        await write.value
        await delete.value

        XCTAssertEqual(store.operations, [.write(HealthNutritionSnapshot(entry: entry)), .delete(entryID: entry.id)])
        XCTAssertNil(store.latestSnapshots[entry.id])
    }

    @MainActor
    func testWriteAfterDeleteRecreatesNutrition() async {
        let store = RecordingHealthNutritionStore()
        let service = HealthKitService(nutritionStore: store, isAvailableOverride: true)
        let entry = makeEntry(version: 2, calories: 125)

        await service.deleteNutrition(for: entry.id)
        await service.writeNutrition(for: entry)

        XCTAssertEqual(store.operations, [.delete(entryID: entry.id), .write(HealthNutritionSnapshot(entry: entry))])
        XCTAssertEqual(store.latestSnapshots[entry.id], HealthNutritionSnapshot(entry: entry))
    }

    @MainActor
    func testDeleteCallsDeleteObjectsForEveryNutrientType() async {
        let entryID = UUID(uuidString: "D79FBA92-2B06-4EB6-A04A-28B908DF43F3")!
        let expectedNutrients: [String] = [
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
        let store = RecordingHealthNutritionStore()
        let error = await HealthNutritionSnapshot.deleteSamples(
            for: entryID,
            authorizedIdentifiers: Set(expectedNutrients),
            store: store
        )

        XCTAssertNil(error)
        XCTAssertEqual(store.deleteObjectsCalls.count, 9)
        XCTAssertEqual(store.deleteObjectsCalls.map { $0.0.identifier }, expectedNutrients)
        for ((_, predicate), nutrient) in zip(store.deleteObjectsCalls, expectedNutrients) {
            XCTAssertTrue(predicate.predicateFormat.contains(HKMetadataKeySyncIdentifier))
            XCTAssertTrue(predicate.predicateFormat.contains("\(entryID.uuidString).\(nutrient)"))
        }
    }

    @MainActor
    func testDeleteSupersedesQueuedUserAndBackfillWrites() async {
        let store = RecordingHealthNutritionStore()
        store.suspendNextApply = true
        let queue = HealthNutritionOperationQueue(
            store: store,
            didEnqueue: { store.recordEnqueued($0) }
        )
        let blocker = HealthNutritionSnapshot(entry: makeEntry(version: 1, calories: 100))
        let target = HealthNutritionSnapshot(entry: makeEntry(version: 2, calories: 125))
        let activeWrite = Task { await queue.enqueue(.write(blocker)) }
        await store.waitUntilSuspended()
        let queuedUserWrite = Task { await queue.enqueue(.write(target)) }
        let queuedBackfillWrite = Task { await queue.enqueueBackfill([.write(target)]) }
        await store.waitUntilEnqueued(count: 3)
        let delete = Task { await queue.enqueue(.delete(entryID: target.entryID)) }
        await store.waitUntilEnqueued(count: 4)
        XCTAssertEqual(store.enqueuedOperations.last, .delete(entryID: target.entryID))

        store.resumeSuspendedApply()
        _ = await activeWrite.value

        let userResult = await queuedUserWrite.value
        let backfillResult = await queuedBackfillWrite.value
        let deleteResult = await delete.value
        XCTAssertEqual(userResult, .superseded)
        XCTAssertEqual(backfillResult, [.superseded])
        XCTAssertEqual(deleteResult, .success)
        XCTAssertEqual(store.operations, [.write(blocker), .delete(entryID: target.entryID)])
        XCTAssertNil(store.latestSnapshots[target.entryID])
    }

    @MainActor
    func testBackfillReportsFailuresAndFirstError() async {
        let store = RecordingHealthNutritionStore()
        store.results = [.failure("Health save failed"), .success, .partial]
        let service = HealthKitService(nutritionStore: store, isAvailableOverride: true)
        let date = Date(timeIntervalSince1970: 0)
        let snapshots = [
            makeSnapshot(version: 1, calories: 100, date: date),
            makeSnapshot(version: 2, calories: 120, date: date),
            makeSnapshot(version: 3, calories: 130, date: date.addingTimeInterval(86_400))
        ]

        let result = await service.backfill(snapshots: snapshots)

        XCTAssertEqual(result.written, 2)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertEqual(result.failed, 1)
        XCTAssertEqual(result.firstError, "Health save failed")
        XCTAssertEqual(result.syncedDayCount, 2)
    }

    @MainActor
    func testBackfillCancellationWaitsForSuspendedStoreOperation() async {
        let store = RecordingHealthNutritionStore()
        store.suspendNextApply = true
        let service = HealthKitService(nutritionStore: store, isAvailableOverride: true)
        let snapshots = (0..<3).map { offset in
            HealthNutritionSnapshot(entry: makeEntry(version: offset, calories: 90 + Double(offset)))
        }
        service.startBackfill(snapshots: snapshots)
        await store.waitUntilSuspended()

        let cancel = Task { await service.cancelBackfill() }
        await Task.yield()
        XCTAssertTrue(service.isBackfilling)
        store.resumeSuspendedApply()
        await cancel.value

        XCTAssertFalse(service.isBackfilling)
        XCTAssertEqual(store.operations.count, 1)
    }

    @MainActor
    private func makeEntry(id: UUID = UUID(), version: Int, calories: Double) -> LogEntry {
        LogEntry(
            id: id,
            dateLogged: Date(timeIntervalSince1970: 100),
            foodName: "Test meal",
            source: .custom,
            servingDescription: "1 serving",
            caloriesPerServing: calories,
            proteinPerServing: 10,
            fatPerServing: 5,
            carbsPerServing: 20,
            quantityMode: .servings,
            servingsConsumed: 1,
            caloriesConsumed: calories,
            proteinConsumed: 10,
            fatConsumed: 5,
            carbsConsumed: 20,
            healthSyncVersion: version
        )
    }

    @MainActor
    private func makeSnapshot(version: Int, calories: Double, date: Date) -> HealthNutritionSnapshot {
        let entry = makeEntry(version: version, calories: calories)
        entry.dateLogged = date
        return HealthNutritionSnapshot(entry: entry)
    }
}

@MainActor
private final class RecordingHealthNutritionStore: HealthNutritionStore {
    private(set) var operations: [HealthNutritionOperation] = []
    private(set) var latestSnapshots: [UUID: HealthNutritionSnapshot] = [:]
    private(set) var enqueuedOperations: [HealthNutritionOperation] = []
    private(set) var deleteObjectsCalls: [(HKQuantityType, NSPredicate)] = []
    var results: [HealthNutritionStoreResult] = []
    var suspendNextApply = false
    private var continuation: CheckedContinuation<Void, Never>?
    private var suspensionWaiters: [CheckedContinuation<Void, Never>] = []
    private var enqueueWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func apply(_ operation: HealthNutritionOperation) async -> HealthNutritionStoreResult {
        operations.append(operation)
        if suspendNextApply {
            suspendNextApply = false
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                let waiters = suspensionWaiters
                suspensionWaiters.removeAll()
                waiters.forEach { $0.resume() }
            }
        }
        switch operation {
        case let .write(snapshot):
            latestSnapshots[snapshot.entryID] = snapshot
        case let .delete(entryID):
            let error = await HealthNutritionSnapshot.deleteSamples(
                for: entryID,
                authorizedIdentifiers: Set(HealthNutritionSnapshot.nutrientIdentifiers),
                store: self
            )
            latestSnapshots[entryID] = nil
            if let error { return .failure(error) }
        }
        return results.isEmpty ? .success : results.removeFirst()
    }

    func deleteObjects(of type: HKQuantityType, predicate: NSPredicate) async throws {
        deleteObjectsCalls.append((type, predicate))
    }

    func recordEnqueued(_ operation: HealthNutritionOperation) {
        enqueuedOperations.append(operation)
        let ready = enqueueWaiters.filter { enqueuedOperations.count >= $0.0 }
        enqueueWaiters.removeAll { enqueuedOperations.count >= $0.0 }
        ready.forEach { $0.1.resume() }
    }

    func waitUntilEnqueued(count: Int) async {
        guard enqueuedOperations.count < count else { return }
        await withCheckedContinuation { continuation in
            enqueueWaiters.append((count, continuation))
        }
    }

    func waitUntilSuspended() async {
        guard continuation == nil else { return }
        await withCheckedContinuation { continuation in
            suspensionWaiters.append(continuation)
        }
    }

    func resumeSuspendedApply() {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume()
    }
}
