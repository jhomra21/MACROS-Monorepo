import Foundation
import SwiftData
import XCTest
@testable import cal_macro_tracker

@MainActor
final class CommonFoodSeedLoaderTests: XCTestCase {
    func testReconcileRenamesFoodInPlaceBySourceIdentifier() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let previous = record(sourceIdentifier: "123", name: "Coffee, Decaffeinated")
        try CommonFoodSeedLoader.reconcile(modelContext: context, records: [previous])
        let existingFood = try XCTUnwrap(context.fetch(FetchDescriptor<FoodItem>()).first)
        let originalID = existingFood.id

        let renamed = record(sourceIdentifier: "123", name: "Coffee, Decaffeinated, Sweetened")
        try CommonFoodSeedLoader.reconcile(modelContext: context, records: [renamed])

        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertEqual(foods.count, 1)
        XCTAssertEqual(foods.first?.id, originalID)
        XCTAssertEqual(foods.first?.name, renamed.name)
        XCTAssertEqual(foods.first?.sourceIdentifier, renamed.sourceIdentifier)
        XCTAssertTrue(foods.first?.searchableText.contains("sweetened") == true)
    }

    func testReconcileDeletesUnreferencedStaleFoodsAndKeepsReferencedOnes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let current = record(sourceIdentifier: "1", name: "Current Food")
        let unreferencedStale = record(sourceIdentifier: "2", name: "Unreferenced Stale Food")
        let referencedStale = record(sourceIdentifier: "3", name: "Referenced Stale Food")
        try CommonFoodSeedLoader.reconcile(modelContext: context, records: [current, unreferencedStale, referencedStale])

        let staleFood = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodItem>())
            .first(where: { $0.sourceIdentifier == referencedStale.sourceIdentifier }))
        context.insert(
            MealComponent(
                mealID: UUID(),
                foodItemID: staleFood.id,
                quantityMode: .servings,
                quantityAmount: 1
            )
        )
        try context.save()

        try CommonFoodSeedLoader.reconcile(modelContext: context, records: [current])

        let remainingFoods = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertEqual(Set(remainingFoods.compactMap(\.sourceIdentifier)), [current.sourceIdentifier, referencedStale.sourceIdentifier])
    }

    func testReconcileBackfillsSourceIdentifierWhenMatchingExistingFoodByName() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let legacyFood = FoodItem(
            name: "Existing Food",
            source: .common,
            servingDescription: "1 serving",
            caloriesPerServing: 100,
            proteinPerServing: 4,
            fatPerServing: 2,
            carbsPerServing: 10
        )
        context.insert(legacyFood)
        try context.save()

        let record = record(sourceIdentifier: "legacy:existing-food", name: "Existing Food")
        try CommonFoodSeedLoader.reconcile(modelContext: context, records: [record])

        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertEqual(foods.count, 1)
        XCTAssertEqual(foods.first?.id, legacyFood.id)
        XCTAssertEqual(foods.first?.sourceIdentifier, record.sourceIdentifier)
    }

    func testReconcileBackfillsRenamedFoodByItsFNDDSDescriptionAlias() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let oldFood = FoodItem(
            name: "Coffee, Decaffeinated",
            source: .common,
            servingDescription: "1 cup",
            caloriesPerServing: 0,
            proteinPerServing: 0,
            fatPerServing: 0,
            carbsPerServing: 0,
            aliases: ["Coffee, decaffeinated, pre-lightened and pre-sweetened with sugar"]
        )
        context.insert(oldFood)
        try context.save()
        let originalID = oldFood.id
        let record = CommonFoodSeedRecord(
            sourceIdentifier: "2710461",
            name: "Coffee, Decaffeinated, Pre-lightened And Pre-sweetened With Sugar",
            aliases: ["Coffee, decaffeinated, pre-lightened and pre-sweetened with sugar"],
            servingDescription: "1 cup",
            gramsPerServing: 240,
            caloriesPerServing: 20,
            proteinPerServing: 1,
            fatPerServing: 1,
            carbsPerServing: 2,
            saturatedFatPerServing: nil,
            fiberPerServing: nil,
            sugarsPerServing: nil,
            addedSugarsPerServing: nil,
            sodiumPerServing: nil,
            cholesterolPerServing: nil
        )

        try CommonFoodSeedLoader.reconcile(modelContext: context, records: [record])

        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertEqual(foods.count, 1)
        XCTAssertEqual(foods.first?.id, originalID)
        XCTAssertEqual(foods.first?.name, record.name)
        XCTAssertEqual(foods.first?.sourceIdentifier, record.sourceIdentifier)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: FoodItem.self, Meal.self, MealComponent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    private func record(sourceIdentifier: String, name: String) -> CommonFoodSeedRecord {
        CommonFoodSeedRecord(
            sourceIdentifier: sourceIdentifier,
            name: name,
            aliases: ["source \(name.lowercased())", name.lowercased()],
            servingDescription: "1 serving",
            gramsPerServing: 100,
            caloriesPerServing: 100,
            proteinPerServing: 4,
            fatPerServing: 2,
            carbsPerServing: 10,
            saturatedFatPerServing: nil,
            fiberPerServing: nil,
            sugarsPerServing: nil,
            addedSugarsPerServing: nil,
            sodiumPerServing: nil,
            cholesterolPerServing: nil
        )
    }
}
