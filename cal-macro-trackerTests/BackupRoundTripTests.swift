import Foundation
import SwiftData
import XCTest
@testable import cal_macro_tracker

@MainActor
final class BackupRoundTripTests: XCTestCase {
    private var container: ModelContainer!
    private var testDefaults: UserDefaults!
    private var testRingDefaults: UserDefaults!

    override func setUpWithError() throws {
        container = try makeContainer()
        let suite = "BackupRoundTripTests.\(UUID().uuidString)"
        testDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        testRingDefaults = try XCTUnwrap(UserDefaults(suiteName: "\(suite).rings"))
    }

    override func tearDownWithError() throws {
        container = nil
        testDefaults = nil
        testRingDefaults = nil
    }

    func testRoundTripDecodedContentMatchesAfterImportAndReexport() throws {
        let context = container.mainContext
        seedRoundTripData(in: context)

        let firstBackup = try makeBackup(
            from: context,
            exportedAt: date("2026-10-25T10:00:00Z"),
            appVersion: "1.2"
        )
        let firstData = try BackupExporter.encode(firstBackup)
        let decoded = try BackupImporter.decode(firstData)

        let importedContainer = try makeContainer()
        defer { _ = importedContainer }
        try apply(decoded, to: importedContainer, mode: .replace)
        let secondBackup = try makeBackup(
            from: importedContainer.mainContext,
            exportedAt: date("2026-10-26T10:00:00Z"),
            appVersion: "1.2"
        )

        XCTAssertEqual(decoded.replacingExportedAt(secondBackup.exportedAt), secondBackup)
    }

    func testRejectsUnknownVersion() throws {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: BackupExporter.encode(backup())) as? [String: Any]
        )
        object["version"] = 99
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try BackupImporter.decode(data)) { error in
            guard case BackupImportError.unsupportedVersion(99) = error else {
                return XCTFail("Expected unsupported-version error, received \(error).")
            }
        }
    }

    func testRejectsCorruptJSON() throws {
        XCTAssertThrowsError(try BackupImporter.decode(Data("{".utf8)))
    }

    func testRejectsNegativeNutrition() throws {
        let food = BackupFood(
            id: UUID(), name: "Invalid", brand: nil, source: .custom, sourceIdentifier: nil,
            barcode: nil, externalProductID: nil, sourceName: nil, sourceURL: nil,
            servingDescription: "1 serving", gramsPerServing: nil, caloriesPerServing: -1,
            proteinPerServing: 0, fatPerServing: 0, carbsPerServing: 0,
            saturatedFatPerServing: nil, fiberPerServing: nil, sugarsPerServing: nil,
            addedSugarsPerServing: nil, sodiumPerServing: nil, cholesterolPerServing: nil,
            secondaryNutrientBackfillState: .current, createdAt: .now, updatedAt: .now
        )
        let backup = MACROSBackup(
            version: 1, exportedAt: .now, appVersion: "1",
            goals: [], bodyProfile: [], foods: [food], meals: [], logEntries: [],
            weightEntries: [], settings: .default
        )
        XCTAssertThrowsError(try BackupImporter.validate(backup))
    }

    func testMergeSkipsExistingIDsAndKeepsExistingValues() throws {
        let context = container.mainContext
        let existing = FoodItem(
            name: "Local Name", source: .custom, servingDescription: "1 serving",
            caloriesPerServing: 10, proteinPerServing: 1, fatPerServing: 1, carbsPerServing: 1)
        context.insert(existing)
        try context.save()

        let incoming = BackupFood(
            id: existing.id, name: "Backup Name", brand: nil, source: .custom, sourceIdentifier: nil,
            barcode: nil, externalProductID: nil, sourceName: nil, sourceURL: nil,
            servingDescription: "1 serving", gramsPerServing: nil, caloriesPerServing: 20,
            proteinPerServing: 2, fatPerServing: 2, carbsPerServing: 2,
            saturatedFatPerServing: nil, fiberPerServing: nil, sugarsPerServing: nil,
            addedSugarsPerServing: nil, sodiumPerServing: nil, cholesterolPerServing: nil,
            secondaryNutrientBackfillState: .current, createdAt: .now, updatedAt: .now
        )
        try apply(backup(foods: [incoming]), to: container, mode: .merge)

        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertEqual(foods.count, 1)
        XCTAssertEqual(foods.first?.name, "Local Name")
        XCTAssertEqual(foods.first?.caloriesPerServing, 10)
    }

    func testReplaceDeletesNonCommonDataAndKeepsCommonFoods() throws {
        let context = container.mainContext
        context.insert(
            FoodItem(
                name: "Seeded", source: .common, servingDescription: "1 serving",
                caloriesPerServing: 10, proteinPerServing: 1, fatPerServing: 1, carbsPerServing: 1))
        context.insert(
            FoodItem(
                name: "Old custom", source: .custom, servingDescription: "1 serving",
                caloriesPerServing: 10, proteinPerServing: 1, fatPerServing: 1, carbsPerServing: 1))
        context.insert(DailyGoals(calorieGoal: 1_900))
        try context.save()

        try apply(backup(), to: container, mode: .replace)

        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertEqual(foods.map(\.sourceKind), [.common])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyGoals>()), 0)
    }

    func testMissingFoodReferenceImportsLogAsSnapshotOnly() throws {
        let entry = BackupLogEntry(
            id: UUID(), foodItemID: UUID(), mealID: nil, dateLogged: date("2026-10-25T12:00:00Z"),
            foodName: "Food no longer available", brand: nil, source: .custom, barcode: nil,
            externalProductID: nil, sourceName: nil, sourceURL: nil, servingDescription: "1 serving",
            gramsPerServing: nil, caloriesPerServing: 100, proteinPerServing: 10, fatPerServing: 2,
            carbsPerServing: 15, saturatedFatPerServing: nil, fiberPerServing: nil, sugarsPerServing: nil,
            addedSugarsPerServing: nil, sodiumPerServing: nil, cholesterolPerServing: nil,
            quantityMode: .servings, servingsConsumed: 1, gramsConsumed: nil, caloriesConsumed: 100,
            proteinConsumed: 10, fatConsumed: 2, carbsConsumed: 15, saturatedFatConsumed: nil,
            fiberConsumed: nil, sugarsConsumed: nil, addedSugarsConsumed: nil, sodiumConsumed: nil,
            cholesterolConsumed: nil, secondaryNutrientBackfillState: .current, healthSyncVersion: 0,
            createdAt: .now, updatedAt: .now, componentSnapshots: []
        )

        try apply(backup(logEntries: [entry]), to: container, mode: .replace)

        let imported = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<LogEntry>()).first)
        XCTAssertNil(imported.foodItemID)
        XCTAssertEqual(imported.foodName, "Food no longer available")
        XCTAssertEqual(imported.caloriesConsumed, 100)
    }

    func testCSVEscapesCommasQuotesAndNewlinesInFoodNames() throws {
        let entry = LogEntry(
            dateLogged: .now, foodName: "Beans, \"red\"\nand white", source: .custom,
            servingDescription: "1 cup", caloriesPerServing: 100, proteinPerServing: 5,
            fatPerServing: 1, carbsPerServing: 20, quantityMode: .servings, servingsConsumed: 1,
            caloriesConsumed: 100, proteinConsumed: 5, fatConsumed: 1, carbsConsumed: 20
        )
        let csv = BackupExporter.csv(for: [entry])
        XCTAssertTrue(csv.contains("\"Beans, \"\"red\"\"\nand white\""))
    }

    func testExportOrderingIsDeterministicApartFromExportedAt() throws {
        seedRoundTripData(in: container.mainContext)
        let first = try BackupExporter.encode(
            makeBackup(
                from: container.mainContext, exportedAt: date("2026-10-25T10:00:00Z"), appVersion: "1"
            ))
        let second = try BackupExporter.encode(
            makeBackup(
                from: container.mainContext, exportedAt: date("2026-10-26T10:00:00Z"), appVersion: "1"
            ))
        let firstBackup = try BackupImporter.decode(first)
        let secondBackup = try BackupImporter.decode(second)

        XCTAssertEqual(firstBackup.replacingExportedAt(secondBackup.exportedAt), secondBackup)
        XCTAssertEqual(
            try BackupExporter.encode(firstBackup.replacingExportedAt(secondBackup.exportedAt)),
            second
        )
    }

    private func seedRoundTripData(in context: ModelContext) {
        let timestamp = date("2026-10-25T08:00:00Z")
        let food = FoodItem(
            name: "Oats", source: .custom, servingDescription: "1 bowl", gramsPerServing: 80,
            caloriesPerServing: 300, proteinPerServing: 12, fatPerServing: 5, carbsPerServing: 50,
            createdAt: timestamp, updatedAt: timestamp
        )
        let meal = Meal(id: UUID(), name: "Breakfast", createdAt: timestamp, updatedAt: timestamp)
        context.insert(food)
        context.insert(meal)
        context.insert(
            MealComponent(
                mealID: meal.id, foodItemID: food.id, quantityMode: .servings,
                quantityAmount: 1, createdAt: timestamp, updatedAt: timestamp))
        context.insert(DailyGoals(calorieGoal: 2_000, createdAt: timestamp, updatedAt: timestamp))
        context.insert(BodyProfile(createdAt: timestamp, updatedAt: timestamp))
        context.insert(
            LogEntry(
                foodItemID: food.id, dateLogged: timestamp, foodName: food.name, source: .custom,
                servingDescription: food.servingDescription, gramsPerServing: 80, caloriesPerServing: 300,
                proteinPerServing: 12, fatPerServing: 5, carbsPerServing: 50, quantityMode: .servings,
                servingsConsumed: 1, caloriesConsumed: 300, proteinConsumed: 12, fatConsumed: 5,
                carbsConsumed: 50, createdAt: timestamp, updatedAt: timestamp
            ))
        context.insert(
            WeightEntry(
                day: "2026-10-25", recordedAt: timestamp, weightKg: 70,
                createdAt: timestamp, updatedAt: timestamp))
    }

    private func backup(foods: [BackupFood] = [], logEntries: [BackupLogEntry] = []) -> MACROSBackup {
        MACROSBackup(
            version: 1, exportedAt: .now, appVersion: "1", goals: [], bodyProfile: [],
            foods: foods, meals: [], logEntries: logEntries, weightEntries: [], settings: .default)
    }

    private func apply(_ backup: MACROSBackup, to target: ModelContainer, mode: BackupImportMode) throws {
        try BackupImporter.apply(
            backup,
            to: target,
            mode: mode,
            standardDefaults: testDefaults,
            ringDefaults: testRingDefaults
        )
    }

    private func makeBackup(from context: ModelContext, exportedAt: Date, appVersion: String) throws -> MACROSBackup {
        try BackupExporter.makeBackup(
            from: context,
            exportedAt: exportedAt,
            appVersion: appVersion,
            settings: .current(standardDefaults: testDefaults, ringDefaults: testRingDefaults)
        )
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: DailyGoals.self, BodyProfile.self, FoodItem.self, Meal.self, MealComponent.self,
            LoggedMealComponentSnapshot.self, LogEntry.self, WeightEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }
}
