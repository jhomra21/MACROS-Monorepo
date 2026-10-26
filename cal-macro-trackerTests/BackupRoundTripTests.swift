import Foundation
import SwiftData
import XCTest
@testable import cal_macro_tracker

@MainActor
final class BackupRoundTripTests: XCTestCase {
    private var container: ModelContainer!
    private var testDefaults: UserDefaults!
    private var testRingDefaults: UserDefaults!
    private var defaultSuites: [String] = []

    override func setUpWithError() throws {
        container = try makeContainer()
        testDefaults = try makeDefaults()
        testRingDefaults = try makeDefaults()
    }

    override func tearDownWithError() throws {
        container = nil
        testDefaults = nil
        testRingDefaults = nil
        for suite in defaultSuites {
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        defaultSuites = []
    }

    func testRoundTripDecodedContentMatchesAfterImportAndReexport() async throws {
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
        let destinationDefaults = try makeDefaults()
        let destinationRings = try makeDefaults()
        BackupSettings.default.apply(standardDefaults: destinationDefaults, ringDefaults: destinationRings)
        XCTAssertNotEqual(decoded.settings, .current(standardDefaults: destinationDefaults, ringDefaults: destinationRings))
        try await apply(
            decoded, to: importedContainer, mode: .replace,
            standardDefaults: destinationDefaults, ringDefaults: destinationRings)
        XCTAssertEqual(decoded.settings, .current(standardDefaults: destinationDefaults, ringDefaults: destinationRings))
        let secondBackup = try makeBackup(
            from: importedContainer.mainContext,
            exportedAt: date("2026-10-26T10:00:00Z"),
            appVersion: "1.2",
            standardDefaults: destinationDefaults, ringDefaults: destinationRings
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

    func testMergeSkipsExistingIDsAndKeepsExistingValues() async throws {
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
        try await apply(backup(foods: [incoming]), to: container, mode: .merge)

        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertEqual(foods.count, 1)
        XCTAssertEqual(foods.first?.name, "Local Name")
        XCTAssertEqual(foods.first?.caloriesPerServing, 10)

        seedRoundTripData(in: context)
        try context.save()
        let original = try makeBackup(from: ModelContext(container), exportedAt: .now, appVersion: "1")
        var changed = original
        changed.goals[0].calorieGoal = 999
        changed.bodyProfile[0].weightKg = 99
        changed.meals[0].name = "Changed meal"
        changed.meals[0].components[0].quantityAmount = 5
        changed.logEntries[0].caloriesConsumed = 999
        changed.logEntries[0].componentSnapshots[0].foodName = "Changed snapshot"
        changed.weightEntries[0].weightKg = 99
        try await apply(changed, to: container, mode: .merge)
        let retained = try makeBackup(
            from: ModelContext(container), exportedAt: original.exportedAt, appVersion: "1")
        XCTAssertEqual(original, retained)
    }

    func testReplaceDeletesNonCommonDataAndKeepsCommonFoods() async throws {
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

        seedRoundTripData(in: context)
        try context.save()
        try await apply(backup(), to: container, mode: .replace)

        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertEqual(foods.map(\.sourceKind), [.common])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyGoals>()), 0)
        let fresh = ModelContext(container)
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<Meal>()), 0)
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<MealComponent>()), 0)
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<LogEntry>()), 0)
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<LoggedMealComponentSnapshot>()), 0)
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<BodyProfile>()), 0)
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<WeightEntry>()), 0)

        let incomingContainer = try makeContainer()
        defer { _ = incomingContainer }
        seedRoundTripData(in: incomingContainer.mainContext)
        try incomingContainer.mainContext.save()
        let incoming = try makeBackup(from: incomingContainer.mainContext, exportedAt: .now, appVersion: "1")
        seedRoundTripData(in: context)
        try context.save()
        try await apply(incoming, to: container, mode: .replace)
        let replaced = try makeBackup(
            from: ModelContext(container), exportedAt: incoming.exportedAt, appVersion: "1")
        XCTAssertEqual(replaced, incoming)
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<FoodItem>()), incoming.foods.count + 1)
    }

    func testMissingFoodReferenceImportsLogAsSnapshotOnly() async throws {
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

        try await apply(backup(logEntries: [entry]), to: container, mode: .replace)

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

    func testLateValidationFailureLeavesReplaceStoreUntouched() async throws {
        seedRoundTripData(in: container.mainContext)
        try container.mainContext.save()
        let before = try makeBackup(from: container.mainContext, exportedAt: .now, appVersion: "1")
        var invalid = before
        invalid.weightEntries[0].weightKg = -1
        invalid.settings = .default
        XCTAssertNotEqual(before.settings, invalid.settings)
        do {
            try await apply(invalid, to: container, mode: .replace)
            XCTFail("Expected invalid weight")
        } catch {
            XCTAssertEqual(error as? BackupImportError, .invalidWeight)
        }
        let after = try makeBackup(from: ModelContext(container), exportedAt: before.exportedAt, appVersion: "1")
        XCTAssertEqual(before, after)
    }

    func testInvalidProfileLeavesReplaceStoreUntouched() async throws {
        try await assertInvalidReplaceLeavesStoreUntouched {
            $0.bodyProfile[0].birthYear = .min
        }
    }

    func testInvalidReminderHourLeavesReplaceStoreUntouched() async throws {
        try await assertInvalidReplaceLeavesStoreUntouched {
            $0.settings.reminders.hour = .max
        }
    }

    func testInvalidRingHexLeavesReplaceStoreUntouched() async throws {
        try await assertInvalidReplaceLeavesStoreUntouched {
            $0.settings.ringColors.proteinHex = "not-a-color"
        }
    }

    func testRejectsInvalidProfileBoundsReminderSlotsAndDates() throws {
        seedRoundTripData(in: container.mainContext)
        let valid = try makeBackup(from: container.mainContext, exportedAt: .now, appVersion: "1")
        let invalidMutations: [(inout MACROSBackup) -> Void] = [
            { $0.bodyProfile[0].birthYear = Calendar.current.component(.year, from: .now) },
            { $0.bodyProfile[0].heightCm = 0 },
            { $0.bodyProfile[0].weightKg = .infinity },
            { $0.bodyProfile[0].goalCalorieOffset = 501 },
            { $0.settings.reminders.minute = 60 },
            { $0.settings.reminders.breakfastHour = -1 },
            { $0.settings.reminders.breakfastMinute = -1 },
            { $0.settings.reminders.lunchHour = 24 },
            { $0.settings.reminders.lunchMinute = 60 },
            { $0.settings.reminders.dinnerHour = .max },
            { $0.settings.reminders.dinnerMinute = .min },
            { $0.settings.ringColors.carbHex = "#GGGGGG" },
            { $0.settings.ringColors.fatHex = "#12345" },
            { $0.exportedAt = Date(timeIntervalSinceReferenceDate: .infinity) },
            { $0.goals[0].createdAt = Date(timeIntervalSinceReferenceDate: .nan) },
            { $0.bodyProfile[0].updatedAt = Date(timeIntervalSinceReferenceDate: .infinity) },
            { $0.foods[0].createdAt = Date(timeIntervalSinceReferenceDate: -.infinity) },
            { $0.meals[0].updatedAt = Date(timeIntervalSinceReferenceDate: .nan) },
            { $0.meals[0].components[0].createdAt = Date(timeIntervalSinceReferenceDate: .infinity) },
            { $0.logEntries[0].dateLogged = Date(timeIntervalSinceReferenceDate: .infinity) },
            { $0.logEntries[0].componentSnapshots[0].createdAt = Date(timeIntervalSinceReferenceDate: .nan) },
            { $0.weightEntries[0].recordedAt = Date(timeIntervalSinceReferenceDate: .infinity) }
        ]
        for (index, mutate) in invalidMutations.enumerated() {
            var invalid = valid
            mutate(&invalid)
            XCTAssertThrowsError(try BackupImporter.validate(invalid), "Mutation \(index)") {
                XCTAssertTrue($0 is BackupImportError)
            }
        }
    }

    private func assertInvalidReplaceLeavesStoreUntouched(
        _ mutate: (inout MACROSBackup) -> Void
    ) async throws {
        seedRoundTripData(in: container.mainContext)
        try container.mainContext.save()
        let before = try makeBackup(from: container.mainContext, exportedAt: .now, appVersion: "1")
        var invalid = before
        invalid.settings = .default
        mutate(&invalid)
        XCTAssertNotEqual(before.settings, invalid.settings)
        do {
            try await apply(invalid, to: container, mode: .replace)
            XCTFail("Expected validation failure")
        } catch {
            XCTAssertTrue(error is BackupImportError)
        }
        let after = try makeBackup(from: ModelContext(container), exportedAt: before.exportedAt, appVersion: "1")
        XCTAssertEqual(before, after)
    }

    func testBundledReferencesRemapAcrossContainers() async throws {
        let source = container.mainContext
        let common = FoodItem(
            name: "Bundled oats", source: .common, sourceIdentifier: "fndds:123",
            servingDescription: "1 bowl", caloriesPerServing: 100,
            proteinPerServing: 1, fatPerServing: 1, carbsPerServing: 20)
        source.insert(common)
        seedRoundTripData(in: source)
        let component = try XCTUnwrap(source.fetch(FetchDescriptor<MealComponent>()).first)
        component.foodItemID = common.id
        let entry = try XCTUnwrap(source.fetch(FetchDescriptor<LogEntry>()).first)
        entry.foodItemID = common.id
        try source.save()
        let document = try makeBackup(from: source, exportedAt: .now, appVersion: "1")
        let target = try makeContainer()
        defer { _ = target }
        let local = FoodItem(
            name: "Bundled oats", source: .common, sourceIdentifier: "fndds:123",
            servingDescription: "1 bowl", caloriesPerServing: 100,
            proteinPerServing: 1, fatPerServing: 1, carbsPerServing: 20)
        target.mainContext.insert(local)
        try target.mainContext.save()
        XCTAssertNotEqual(common.id, local.id)
        try await apply(document, to: target, mode: .replace)
        let fresh = ModelContext(target)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<MealComponent>()).first?.foodItemID, local.id)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<LogEntry>()).first?.foodItemID, local.id)
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
        let entry = LogEntry(
            foodItemID: food.id, mealID: meal.id, dateLogged: timestamp, foodName: food.name, source: .custom,
            servingDescription: food.servingDescription, gramsPerServing: 80, caloriesPerServing: 300,
            proteinPerServing: 12, fatPerServing: 5, carbsPerServing: 50, quantityMode: .servings,
            servingsConsumed: 1, caloriesConsumed: 300, proteinConsumed: 12, fatConsumed: 5,
            carbsConsumed: 50, createdAt: timestamp, updatedAt: timestamp
        )
        context.insert(entry)
        context.insert(
            LoggedMealComponentSnapshot(
                logEntryID: entry.id, mealID: meal.id, foodItemID: food.id, foodName: food.name,
                quantityMode: .servings, quantityAmount: 1, caloriesConsumed: 300,
                proteinConsumed: 12, fatConsumed: 5, carbsConsumed: 50, createdAt: timestamp))
        var settings = BackupSettings.default
        settings.ringColors.proteinHex = "#123456"
        settings.ringColors.carbHex = "#654321"
        settings.ringColors.fatHex = "#ABCDEF"
        settings.isFoodSuggestionsEnabled = false
        settings.reminders.enabled = true
        settings.reminders.hour = 19
        settings.reminders.minute = 15
        settings.reminders.breakfastEnabled = true
        settings.reminders.breakfastHour = 7
        settings.reminders.breakfastMinute = 30
        settings.reminders.lunchEnabled = true
        settings.reminders.lunchHour = 13
        settings.reminders.lunchMinute = 45
        settings.reminders.dinnerEnabled = true
        settings.reminders.dinnerHour = 17
        settings.reminders.dinnerMinute = 20
        settings.reminders.smartEveningEnabled = true
        settings.apply(standardDefaults: testDefaults, ringDefaults: testRingDefaults)
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

    private func apply(
        _ backup: MACROSBackup, to target: ModelContainer, mode: BackupImportMode,
        standardDefaults: UserDefaults? = nil, ringDefaults: UserDefaults? = nil
    ) async throws {
        try await BackupImporter.apply(
            backup,
            to: target,
            mode: mode,
            standardDefaults: standardDefaults ?? testDefaults,
            ringDefaults: ringDefaults ?? testRingDefaults
        )
    }

    private func makeBackup(
        from context: ModelContext, exportedAt: Date, appVersion: String,
        standardDefaults: UserDefaults? = nil, ringDefaults: UserDefaults? = nil
    ) throws -> MACROSBackup {
        try BackupExporter.makeBackup(
            from: context,
            exportedAt: exportedAt,
            appVersion: appVersion,
            settings: .current(
                standardDefaults: standardDefaults ?? testDefaults, ringDefaults: ringDefaults ?? testRingDefaults)
        )
    }

    private func makeDefaults() throws -> UserDefaults {
        let suite = "BackupRoundTripTests.\(UUID().uuidString)"
        defaultSuites.append(suite)
        return try XCTUnwrap(UserDefaults(suiteName: suite))
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
