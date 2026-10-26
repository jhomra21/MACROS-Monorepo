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
        let service = HealthKitService(nutritionStore: store, isAvailableOverride: true)
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
        let service = HealthKitService(nutritionStore: store, isAvailableOverride: true)
        let entry = makeEntry(version: 1, calories: 100)

        let write = Task { await service.writeNutrition(for: entry) }
        await store.waitUntilSuspended()
        let delete = Task { await service.deleteNutrition(for: entry.id) }
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
    func testDeleteSnapshotCoversEveryNutrientType() {
        let entryID = UUID(uuidString: "D79FBA92-2B06-4EB6-A04A-28B908DF43F3")!
        let expectedNutrients = [
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
        let expectedIdentifiers = expectedNutrients.map { "\(entryID.uuidString).\($0)" }

        XCTAssertEqual(HealthNutritionSnapshot.deletionIdentifiers(for: entryID), expectedIdentifiers)
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
}

@MainActor
private final class RecordingHealthNutritionStore: HealthNutritionStore {
    private(set) var operations: [HealthNutritionOperation] = []
    private(set) var latestSnapshots: [UUID: HealthNutritionSnapshot] = [:]
    var suspendNextApply = false
    private var continuation: CheckedContinuation<Void, Never>?
    private var suspensionWaiters: [CheckedContinuation<Void, Never>] = []

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
            latestSnapshots[entryID] = nil
        }
        return .success
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
