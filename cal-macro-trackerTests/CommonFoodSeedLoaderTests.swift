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

    func testReconcileClaimsStoredFoodOnlyOnceAcrossDescriptionAndNameMatches() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let sharedFood = FoodItem(
            name: "Existing Name",
            source: .common,
            servingDescription: "1 serving",
            caloriesPerServing: 40,
            proteinPerServing: 2,
            fatPerServing: 1,
            carbsPerServing: 5,
            aliases: ["shared source description"]
        )
        context.insert(sharedFood)
        try context.save()

        let nameMatch = record(sourceIdentifier: "fndds:00000001", name: "Existing Name")
        let descriptionMatch = record(sourceIdentifier: "fndds:00000002", name: "Renamed Food")
        let originalID = sharedFood.id
        let descriptionMatchRecord = CommonFoodSeedRecord(
            sourceIdentifier: descriptionMatch.sourceIdentifier,
            name: descriptionMatch.name,
            aliases: ["shared source description"],
            servingDescription: descriptionMatch.servingDescription,
            gramsPerServing: descriptionMatch.gramsPerServing,
            caloriesPerServing: 210,
            proteinPerServing: 11,
            fatPerServing: 7,
            carbsPerServing: 24,
            saturatedFatPerServing: nil,
            fiberPerServing: nil,
            sugarsPerServing: nil,
            addedSugarsPerServing: nil,
            sodiumPerServing: nil,
            cholesterolPerServing: nil
        )

        try CommonFoodSeedLoader.reconcile(
            modelContext: context,
            records: [nameMatch, descriptionMatchRecord]
        )

        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        let claimedFood = try XCTUnwrap(foods.first { $0.sourceIdentifier == nameMatch.sourceIdentifier })
        let insertedFood = try XCTUnwrap(foods.first { $0.sourceIdentifier == descriptionMatch.sourceIdentifier })
        XCTAssertEqual(foods.count, 2)
        XCTAssertEqual(claimedFood.id, originalID)
        XCTAssertEqual(claimedFood.sourceIdentifier, nameMatch.sourceIdentifier)
        XCTAssertEqual(claimedFood.caloriesPerServing, nameMatch.caloriesPerServing)
        XCTAssertEqual(claimedFood.proteinPerServing, nameMatch.proteinPerServing)
        XCTAssertEqual(claimedFood.fatPerServing, nameMatch.fatPerServing)
        XCTAssertEqual(claimedFood.carbsPerServing, nameMatch.carbsPerServing)
        XCTAssertNotEqual(insertedFood.id, originalID)
        XCTAssertEqual(insertedFood.sourceIdentifier, descriptionMatchRecord.sourceIdentifier)
        XCTAssertEqual(insertedFood.caloriesPerServing, descriptionMatchRecord.caloriesPerServing)
        XCTAssertEqual(insertedFood.proteinPerServing, descriptionMatchRecord.proteinPerServing)
        XCTAssertEqual(insertedFood.fatPerServing, descriptionMatchRecord.fatPerServing)
        XCTAssertEqual(insertedFood.carbsPerServing, descriptionMatchRecord.carbsPerServing)
    }

    func testReconcileBackfillsSameNameFoodDeterministically() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let earlierFood = FoodItem(
            name: "Duplicate Name",
            source: .common,
            servingDescription: "1 serving",
            caloriesPerServing: 10,
            proteinPerServing: 1,
            fatPerServing: 1,
            carbsPerServing: 1,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let laterFood = FoodItem(
            name: "Duplicate Name",
            source: .common,
            servingDescription: "1 serving",
            caloriesPerServing: 20,
            proteinPerServing: 2,
            fatPerServing: 2,
            carbsPerServing: 2,
            createdAt: Date(timeIntervalSince1970: 200)
        )
        context.insert(laterFood)
        context.insert(earlierFood)
        try context.save()
        let record = record(sourceIdentifier: "fndds:00000003", name: "Duplicate Name")

        try CommonFoodSeedLoader.reconcile(modelContext: context, records: [record])
        let firstSurvivor = try XCTUnwrap(context.fetch(FetchDescriptor<FoodItem>()).first)
        try CommonFoodSeedLoader.reconcile(modelContext: context, records: [record])
        let secondSurvivor = try XCTUnwrap(context.fetch(FetchDescriptor<FoodItem>()).first)

        XCTAssertEqual(firstSurvivor.id, earlierFood.id)
        XCTAssertEqual(secondSurvivor.id, earlierFood.id)
        XCTAssertEqual(secondSurvivor.caloriesPerServing, record.caloriesPerServing)
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
