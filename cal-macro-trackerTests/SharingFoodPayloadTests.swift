import SwiftData
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

        XCTAssertEqual(
            SharedFoodPayload(entry: entry, sortIndex: 3).quantityText,
            String(entry.quantitySummary.prefix(40))
        )
        XCTAssertEqual(payload.name.count, 80)
        XCTAssertEqual(payload.quantityText.count, 40)
        XCTAssertEqual(
            Set(payload.convexArguments.keys),
            Set(["localEntryId", "sortIndex", "name", "quantityText", "calories", "protein", "carbs", "fat"])
        )
        XCTAssertEqual(payload.localEntryId, entry.id.uuidString)
    }

    func testFoodPayloadTruncatesEmojiOnUtf16Boundary() {
        let payload = SharedFoodPayload(
            localEntryId: UUID().uuidString,
            sortIndex: 0,
            name: String(repeating: "😀", count: 50),
            quantityText: String(repeating: "🥗", count: 25),
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0
        )

        XCTAssertEqual(payload.name.utf16.count, 80)
        XCTAssertEqual(payload.quantityText.utf16.count, 40)
        XCTAssertEqual(payload.name, String(repeating: "😀", count: 40))
        XCTAssertEqual(payload.quantityText, String(repeating: "🥗", count: 20))
    }

    func testPurchaseSubmissionDedupeIncludesRenewalInfo() {
        var deduplicator = PurchaseSubmissionDeduplicator()
        let expiry = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertTrue(deduplicator.insert(transactionID: 42, expiresAt: expiry, renewalInfo: "renewal-a"))
        XCTAssertFalse(deduplicator.insert(transactionID: 42, expiresAt: expiry, renewalInfo: "renewal-a"))
        XCTAssertTrue(deduplicator.insert(transactionID: 42, expiresAt: expiry, renewalInfo: "renewal-b"))
    }

    func testFoodPayloadUsesDashboardQuantitySummaryWithServingDescription() {
        let entry = LogEntry(
            dateLogged: .now,
            foodName: "Oats",
            source: .custom,
            servingDescription: "1 cup",
            gramsPerServing: 40,
            caloriesPerServing: 150,
            proteinPerServing: 5,
            fatPerServing: 3,
            carbsPerServing: 27,
            quantityMode: .servings,
            servingsConsumed: 2,
            caloriesConsumed: 300,
            proteinConsumed: 10,
            fatConsumed: 6,
            carbsConsumed: 54
        )

        XCTAssertEqual(SharedFoodPayload(entry: entry, sortIndex: 0).quantityText, "2 × 1 cup (40 g)")
    }

    func testServingQuantitySummaryPreservesUpToTwoDecimalPlaces() {
        func entry(servings: Double) -> LogEntry {
            LogEntry(
                dateLogged: .now,
                foodName: "Oats",
                source: .custom,
                servingDescription: "cup",
                caloriesPerServing: 150,
                proteinPerServing: 5,
                fatPerServing: 3,
                carbsPerServing: 27,
                quantityMode: .servings,
                servingsConsumed: servings,
                caloriesConsumed: 150 * servings,
                proteinConsumed: 5 * servings,
                fatConsumed: 3 * servings,
                carbsConsumed: 27 * servings
            )
        }

        XCTAssertEqual(entry(servings: 1.25).quantitySummary, "1.25 × cup")
        XCTAssertEqual(entry(servings: 1.5).quantitySummary, "1.5 × cup")
        XCTAssertEqual(entry(servings: 2).quantitySummary, "2 × cup")
    }

    func testPersonDayVisibilityDefaultsToSharedAndDecodesCurrentStates() throws {
        func decode(_ visibility: String?) throws -> SharingPersonDay {
            let visibilityField = visibility.map { "\"visibility\":\"\($0)\"," } ?? ""
            return try JSONDecoder().decode(
                SharingPersonDay.self,
                from: Data("{\(visibilityField)\"snapshot\":null,\"foods\":[]}".utf8)
            )
        }

        XCTAssertEqual(try decode(nil).visibility, .shared)
        XCTAssertEqual(try decode("notShared").visibility, .notShared)
        XCTAssertEqual(try decode("paused").visibility, .paused)
    }

    @MainActor
    func testUploadPayloadCapsFoodsAtFirstHundredBySortIndex() throws {
        let container = try ModelContainer(
            for: DailyGoals.self, FoodItem.self, Meal.self, MealComponent.self,
            LoggedMealComponentSnapshot.self, LogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = ModelContext(container)
        let date = Date.now
        let entries = (0..<101).map { index in
            LogEntry(
                dateLogged: date.addingTimeInterval(TimeInterval(index)),
                foodName: "Food \(index)",
                source: .custom,
                servingDescription: "1 serving",
                caloriesPerServing: 1,
                proteinPerServing: 0,
                fatPerServing: 0,
                carbsPerServing: 0,
                quantityMode: .servings,
                servingsConsumed: 1,
                caloriesConsumed: 1,
                proteinConsumed: 0,
                fatConsumed: 0,
                carbsConsumed: 0
            )
        }
        entries.forEach(context.insert)
        try context.save()

        let payload = try SharingUploadCoordinator().payload(
            container: container,
            date: date.addingTimeInterval(50),
            calendar: .current,
            includeFoods: true
        )

        XCTAssertEqual(payload.foods?.count, 100)
        XCTAssertEqual(payload.foods?.map(\.sortIndex), Array(0..<100))
        XCTAssertEqual(payload.foods?.first?.name, "Food 0")
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

    @MainActor
    func testDailyGoalsAreIncludedInPayloadAndStableHash() throws {
        let container = try ModelContainer(
            for: DailyGoals.self, FoodItem.self, Meal.self, MealComponent.self,
            LoggedMealComponentSnapshot.self, LogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = ModelContext(container)
        context.insert(DailyGoals(calorieGoal: 2_100, proteinGoalGrams: 145, fatGoalGrams: 65, carbGoalGrams: 230))
        try context.save()
        let payload = try SharingUploadCoordinator().payload(
            container: container,
            date: .now,
            calendar: .current,
            includeFoods: false
        )
        let snapshotArguments = try XCTUnwrap(payload.convexArguments["snapshot"] as? [String: Any])
        XCTAssertEqual(snapshotArguments["calorieGoal"] as? Double, 2_100)
        XCTAssertEqual(snapshotArguments["proteinGoal"] as? Double, 145)
        XCTAssertEqual(snapshotArguments["carbsGoal"] as? Double, 230)
        XCTAssertEqual(snapshotArguments["fatGoal"] as? Double, 65)

        let changedGoal = SharingDailySnapshotPayload(
            day: payload.day,
            timeZoneId: payload.timeZoneId,
            calories: payload.calories,
            protein: payload.protein,
            fat: payload.fat,
            carbs: payload.carbs,
            entryCount: payload.entryCount,
            calorieGoal: 2_200,
            proteinGoal: payload.proteinGoal,
            carbsGoal: payload.carbsGoal,
            fatGoal: payload.fatGoal
        )
        XCTAssertNotEqual(payload.stableHash, changedGoal.stableHash)
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

        XCTAssertTrue(deduplicator.insert(transactionID: 42, expiresAt: expiry, renewalInfo: nil))
        XCTAssertFalse(deduplicator.insert(transactionID: 42, expiresAt: expiry, renewalInfo: nil))
        XCTAssertTrue(
            deduplicator.insert(transactionID: 42, expiresAt: expiry.addingTimeInterval(1), renewalInfo: nil)
        )
    }

    func testSharingPersonDecodingUsesLegacyDefaults() throws {
        let data = Data(
            """
            {
              "relationshipId": "relationship",
              "profileId": "profile",
              "displayName": "Alex",
              "incomingActive": true,
              "outgoingActive": true,
              "scope": { "macros": true }
            }
            """.utf8
        )
        let person = try JSONDecoder().decode(SharingPerson.self, from: data)

        XCTAssertFalse(person.foodsShared)
        XCTAssertFalse(person.connectionPaused)
        XCTAssertEqual(person.outgoingScope, .macros)
    }

    func testSharedDailySnapshotDecodesGoalsAndLegacySnapshots() throws {
        let legacySnapshot = """
        {
          "day": "2026-11-01",
          "timeZoneId": "UTC",
          "calories": 1200,
          "protein": 100,
          "fat": 50,
          "carbs": 140,
          "entryCount": 3,
          "updatedAt": 1
        }
        """
        let goalsSnapshot = """
        {
          "day": "2026-11-01",
          "timeZoneId": "UTC",
          "calories": 1200,
          "protein": 100,
          "fat": 50,
          "carbs": 140,
          "entryCount": 3,
          "updatedAt": 1,
          "calorieGoal": 2100,
          "proteinGoal": 145,
          "carbsGoal": 230,
          "fatGoal": 65
        }
        """

        let legacy = try JSONDecoder().decode(SharedDailySnapshot.self, from: Data(legacySnapshot.utf8))
        let withGoals = try JSONDecoder().decode(SharedDailySnapshot.self, from: Data(goalsSnapshot.utf8))

        XCTAssertNil(legacy.macroGoalsSnapshot)
        XCTAssertEqual(
            withGoals.macroGoalsSnapshot,
            MacroGoalsSnapshot(calorieGoal: 2_100, proteinGoalGrams: 145, fatGoalGrams: 65, carbGoalGrams: 230)
        )
    }
}
