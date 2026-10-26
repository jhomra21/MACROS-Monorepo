import Foundation
import SwiftData
import XCTest
@testable import cal_macro_tracker

@MainActor
final class MealSchemaMigrationTests: XCTestCase {
    private let legacyLogID = UUID(uuidString: "A9C6E2A4-C583-4BD0-AD7D-BB7F03670E31")!
    private let legacyFoodID = UUID(uuidString: "57BA5F1A-1A65-41B8-9AE5-CA8B5CA48192")!
    private let legacyGoalsID = UUID(uuidString: "26591B13-968F-41AA-A037-F72AB3A6A794")!
    private let newMealID = UUID(uuidString: "A2052548-82E8-4FF8-98CE-7EB0CE9594FC")!
    private let newMealLogID = UUID(uuidString: "A4504328-7345-46E0-A414-3AF0C0AB306F")!
    private let newSnapshotID = UUID(uuidString: "44D23974-D672-417D-9451-6D16FFFD0622")!

    func testPreMealStoreMigratesPreservesDataAndReopensWithMealRecords() throws {
        let fixture = try fixtureDirectory()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MealSchemaMigrationQA-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appendingPathComponent("PreMeal.sqlite")
        try copyStoreArtifacts(from: fixture, to: storeURL)
        let configuration = ModelConfiguration(
            "PreMealMigrationQA",
            schema: currentSchema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            let container = try makeContainer(configuration)
            let context = container.mainContext
            try assertLegacyRecords(in: context, expectedLogCount: 1)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<Meal>()), 0)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealComponent>()), 0)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<LoggedMealComponentSnapshot>()), 0)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<BodyProfile>()), 0)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<WeightEntry>()), 0)

            let meal = Meal(
                id: newMealID,
                name: "QA Migration Meal",
                componentNames: ["QA Fixture Oats"],
                createdAt: fixtureDate,
                updatedAt: fixtureDate
            )
            context.insert(meal)
            context.insert(
                MealComponent(
                    mealID: newMealID,
                    foodItemID: legacyFoodID,
                    quantityMode: .servings,
                    quantityAmount: 1,
                    createdAt: fixtureDate,
                    updatedAt: fixtureDate
                )
            )
            context.insert(
                LogEntry(
                    id: newMealLogID,
                    mealID: newMealID,
                    dateLogged: fixtureDate,
                    foodName: meal.name,
                    source: .custom,
                    servingDescription: "1 meal",
                    caloriesPerServing: 307.5,
                    proteinPerServing: 12.25,
                    fatPerServing: 5.75,
                    carbsPerServing: 49.5,
                    quantityMode: .servings,
                    servingsConsumed: 1,
                    caloriesConsumed: 307.5,
                    proteinConsumed: 12.25,
                    fatConsumed: 5.75,
                    carbsConsumed: 49.5,
                    healthSyncVersion: 3,
                    createdAt: fixtureDate,
                    updatedAt: fixtureDate
                )
            )
            context.insert(
                WeightEntry(
                    day: "2026-10-12",
                    recordedAt: fixtureDate,
                    weightKg: 75.4
                )
            )
            context.insert(
                LoggedMealComponentSnapshot(
                    id: newSnapshotID,
                    logEntryID: newMealLogID,
                    mealID: newMealID,
                    foodItemID: legacyFoodID,
                    foodName: "QA Fixture Oats",
                    quantityMode: .servings,
                    quantityAmount: 1,
                    caloriesConsumed: 307.5,
                    proteinConsumed: 12.25,
                    fatConsumed: 5.75,
                    carbsConsumed: 49.5,
                    fiberConsumed: 8,
                    createdAt: fixtureDate
                )
            )
            try context.save()
        }

        let reopened = try makeContainer(configuration)
        let context = reopened.mainContext
        try assertLegacyRecords(in: context, expectedLogCount: 2)
        let newMeal = try XCTUnwrap(
            context.fetch(FetchDescriptor<Meal>()).first(where: { $0.id == newMealID })
        )
        XCTAssertEqual(newMeal.name, "QA Migration Meal")
        let component = try XCTUnwrap(context.fetch(FetchDescriptor<MealComponent>()).first)
        XCTAssertEqual(component.mealID, newMealID)
        XCTAssertEqual(component.foodItemID, legacyFoodID)
        XCTAssertEqual(component.quantityModeKind, .servings)
        XCTAssertEqual(component.quantityAmount, 1)
        let mealLog = try XCTUnwrap(
            context.fetch(FetchDescriptor<LogEntry>()).first(where: { $0.id == newMealLogID })
        )
        XCTAssertEqual(mealLog.mealID, newMealID)
        XCTAssertEqual(mealLog.healthSyncVersion, 3)
        XCTAssertEqual(mealLog.dateLogged, fixtureDate)
        XCTAssertEqual(mealLog.servingsConsumed, 1)
        XCTAssertEqual(mealLog.caloriesConsumed, 307.5)
        let snapshot = try XCTUnwrap(
            context.fetch(FetchDescriptor<LoggedMealComponentSnapshot>())
                .first(where: { $0.id == newSnapshotID })
        )
        XCTAssertEqual(snapshot.logEntryID, newMealLogID)
        XCTAssertEqual(snapshot.mealID, newMealID)
        XCTAssertEqual(snapshot.foodItemID, legacyFoodID)
        XCTAssertEqual(snapshot.foodName, "QA Fixture Oats")
        XCTAssertEqual(snapshot.quantityModeKind, .servings)
        XCTAssertEqual(snapshot.quantityAmount, 1)
        XCTAssertEqual(snapshot.caloriesConsumed, 307.5)
        XCTAssertEqual(snapshot.proteinConsumed, 12.25)
        XCTAssertEqual(snapshot.fatConsumed, 5.75)
        XCTAssertEqual(snapshot.carbsConsumed, 49.5)
        XCTAssertEqual(snapshot.fiberConsumed, 8)
        let weightEntry = try XCTUnwrap(context.fetch(FetchDescriptor<WeightEntry>()).first)
        XCTAssertEqual(weightEntry.day, "2026-10-12")
        XCTAssertEqual(weightEntry.weightKg, 75.4)
    }

    private var currentSchema: Schema {
        Schema([
            DailyGoals.self,
            BodyProfile.self,
            FoodItem.self,
            Meal.self,
            MealComponent.self,
            LoggedMealComponentSnapshot.self,
            LogEntry.self,
            WeightEntry.self
        ])
    }

    private var fixtureDate: Date {
        ISO8601DateFormatter().date(from: "2026-10-12T12:00:00Z")!
    }

    private func fixtureDirectory() throws -> URL {
        let bundle = Bundle(for: Self.self)
        let storeURL = try XCTUnwrap(
            bundle.url(
                forResource: "PreMeal",
                withExtension: "sqlite"
            )
        )
        return storeURL.deletingLastPathComponent()
    }

    private func copyStoreArtifacts(from sourceDirectory: URL, to storeURL: URL) throws {
        for filename in ["PreMeal.sqlite", "PreMeal.sqlite-wal", "PreMeal.sqlite-shm"] {
            let sourceURL = sourceDirectory.appendingPathComponent(filename)
            guard FileManager.default.fileExists(atPath: sourceURL.path) else { continue }
            try FileManager.default.copyItem(
                at: sourceURL,
                to: storeURL.deletingLastPathComponent().appendingPathComponent(filename)
            )
        }
    }

    private func makeContainer(_ configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(for: currentSchema, configurations: configuration)
    }

    private func assertLegacyRecords(in context: ModelContext, expectedLogCount: Int) throws {
        let entries = try context.fetch(FetchDescriptor<LogEntry>())
        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        let goals = try context.fetch(FetchDescriptor<DailyGoals>())
        let log = entries.first(where: { $0.id == legacyLogID })
        let food = foods.first(where: { $0.id == legacyFoodID })
        let dailyGoals = goals.first(where: { $0.id == legacyGoalsID })

        XCTAssertEqual(entries.count, expectedLogCount)
        XCTAssertEqual(foods.count, 1)
        XCTAssertEqual(goals.count, 1)
        XCTAssertEqual(log?.foodItemID, legacyFoodID)
        XCTAssertNil(log?.mealID)
        XCTAssertEqual(log?.dateLogged, fixtureDate)
        XCTAssertEqual(log?.foodName, "QA Fixture Oats")
        XCTAssertEqual(log?.servingDescription, "1 bowl")
        XCTAssertEqual(log?.gramsPerServing, 80)
        XCTAssertEqual(log?.quantityModeKind, .servings)
        XCTAssertEqual(log?.servingsConsumed, 1)
        XCTAssertEqual(log?.caloriesPerServing, 307.5)
        XCTAssertEqual(log?.proteinPerServing, 12.25)
        XCTAssertEqual(log?.fatPerServing, 5.75)
        XCTAssertEqual(log?.carbsPerServing, 49.5)
        XCTAssertEqual(log?.caloriesConsumed, 307.5)
        XCTAssertEqual(log?.proteinConsumed, 12.25)
        XCTAssertEqual(log?.fatConsumed, 5.75)
        XCTAssertEqual(log?.carbsConsumed, 49.5)
        XCTAssertEqual(log?.fiberConsumed, 8)
        XCTAssertEqual(food?.name, "QA Fixture Oats")
        XCTAssertNil(food?.sourceIdentifier)
        XCTAssertEqual(food?.servingDescription, "1 bowl")
        XCTAssertEqual(food?.gramsPerServing, 80)
        XCTAssertEqual(food?.caloriesPerServing, 307.5)
        XCTAssertEqual(food?.proteinPerServing, 12.25)
        XCTAssertEqual(food?.fatPerServing, 5.75)
        XCTAssertEqual(food?.carbsPerServing, 49.5)
        XCTAssertEqual(food?.fiberPerServing, 8)
        XCTAssertEqual(dailyGoals?.calorieGoal, 2_100)
        XCTAssertEqual(dailyGoals?.proteinGoalGrams, 145)
        XCTAssertEqual(dailyGoals?.fatGoalGrams, 68)
        XCTAssertEqual(dailyGoals?.carbGoalGrams, 230)
    }
}
