import XCTest
@testable import cal_macro_tracker

final class SharingFoodPayloadTests: XCTestCase {
    func testFoodPayloadUsesOnlyWhitelistedFieldsAndTrimsText() {
        let name = String(repeating: "N", count: 90)
        let quantity = String(repeating: "Q", count: 50)
        let entry = LogEntry(
            dateLogged: .now,
            foodName: "  \(name)  ",
            brand: "Private brand",
            source: .custom,
            barcode: "private barcode",
            servingDescription: quantity,
            caloriesPerServing: 120,
            proteinPerServing: 5,
            fatPerServing: 2,
            carbsPerServing: 20,
            quantityMode: .servings,
            servingsConsumed: 1,
            caloriesConsumed: 120,
            proteinConsumed: 5,
            fatConsumed: 2,
            carbsConsumed: 20
        )
        let payload = SharedFoodPayload(
            localEntryId: entry.id.uuidString,
            sortIndex: 3,
            name: "  \(name)  ",
            quantityText: "  \(quantity)  ",
            calories: entry.caloriesConsumed,
            protein: entry.proteinConsumed,
            carbs: entry.carbsConsumed,
            fat: entry.fatConsumed
        )

        XCTAssertEqual(SharedFoodPayload(entry: entry, sortIndex: 3).quantityText, entry.quantitySummary)
        XCTAssertEqual(payload.name.count, 80)
        XCTAssertEqual(payload.quantityText.count, 40)
        XCTAssertEqual(
            Set(payload.convexArguments.keys),
            Set(["localEntryId", "sortIndex", "name", "quantityText", "calories", "protein", "carbs", "fat"])
        )
        XCTAssertEqual(payload.localEntryId, entry.id.uuidString)
    }

    func testFoodChangesContributeToUploadHash() {
        let base = SharingDailySnapshotPayload(
            day: "2026-11-01",
            timeZoneId: "UTC",
            calories: 120,
            protein: 5,
            fat: 2,
            carbs: 20,
            entryCount: 1
        )
        let foodA = SharedFoodPayload(
            localEntryId: UUID().uuidString,
            sortIndex: 0,
            name: "Oats",
            quantityText: "1 serving",
            calories: 120,
            protein: 5,
            carbs: 20,
            fat: 2
        )
        let payloadA = SharingDailySnapshotPayload(
            day: base.day,
            timeZoneId: base.timeZoneId,
            calories: base.calories,
            protein: base.protein,
            fat: base.fat,
            carbs: base.carbs,
            entryCount: base.entryCount,
            foods: [foodA]
        )
        let payloadB = SharingDailySnapshotPayload(
            day: base.day,
            timeZoneId: base.timeZoneId,
            calories: base.calories,
            protein: base.protein,
            fat: base.fat,
            carbs: base.carbs,
            entryCount: base.entryCount,
            foods: [
                SharedFoodPayload(
                    localEntryId: foodA.localEntryId,
                    sortIndex: foodA.sortIndex,
                    name: "Granola",
                    quantityText: foodA.quantityText,
                    calories: foodA.calories,
                    protein: foodA.protein,
                    carbs: foodA.carbs,
                    fat: foodA.fat
                )
            ]
        )

        XCTAssertNotEqual(payloadA.stableHash, payloadB.stableHash)
        XCTAssertNotEqual(payloadA.stableHash, base.stableHash)
    }

    func testFoodsAreOmittedWhenNoRecipientHasFoodScope() {
        let payload = SharingDailySnapshotPayload(
            day: "2026-11-01",
            timeZoneId: "UTC",
            calories: 0,
            protein: 0,
            fat: 0,
            carbs: 0,
            entryCount: 0
        )

        XCTAssertNil(payload.foods)
        XCTAssertNil(payload.convexArguments["foods"] ?? nil)
    }

    func testPurchaseSubmissionDeduplicatesByTransactionAndExpiry() {
        var deduplicator = PurchaseSubmissionDeduplicator()
        let expiry = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertTrue(deduplicator.insert(transactionID: 42, expiresAt: expiry))
        XCTAssertFalse(deduplicator.insert(transactionID: 42, expiresAt: expiry))
        XCTAssertTrue(deduplicator.insert(transactionID: 42, expiresAt: expiry.addingTimeInterval(1)))
    }
}
