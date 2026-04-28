import Foundation
import SwiftData

struct CommonFoodSeedRecord: Decodable, Sendable {
    let name: String
    let aliases: [String]
    let servingDescription: String
    let gramsPerServing: Double?
    let caloriesPerServing: Double
    let proteinPerServing: Double
    let fatPerServing: Double
    let carbsPerServing: Double
    let saturatedFatPerServing: Double?
    let fiberPerServing: Double?
    let sugarsPerServing: Double?
    let addedSugarsPerServing: Double?
    let sodiumPerServing: Double?
    let cholesterolPerServing: Double?
}

enum CommonFoodSeedLoader {
    static func commonFoodSeedRecords() async throws -> [CommonFoodSeedRecord] {
        let url = try commonFoodSeedURL()
        return try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([CommonFoodSeedRecord].self, from: data)
        }.value
    }

    static func commonFoodSeedURL() throws -> URL {
        guard let url = Bundle.main.url(forResource: "common_foods", withExtension: "json") else {
            throw NSError(
                domain: "CommonFoodSeedLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing common_foods.json resource."])
        }

        return url
    }

    static func seedIfNeeded(modelContext: ModelContext, records: [CommonFoodSeedRecord]? = nil) throws {
        try reconcile(modelContext: modelContext, records: records)
    }

    static func reconcile(modelContext: ModelContext, records: [CommonFoodSeedRecord]? = nil) throws {
        let commonSource = FoodSource.common.rawValue
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.source == commonSource })
        let existingFoods = try modelContext.fetch(descriptor)

        let foods: [CommonFoodSeedRecord]
        if let records {
            foods = records
        } else {
            let url = try commonFoodSeedURL()
            let data = try Data(contentsOf: url)
            foods = try JSONDecoder().decode([CommonFoodSeedRecord].self, from: data)
        }

        var existingFoodsByName: [String: FoodItem] = [:]
        for food in existingFoods {
            let name = normalizedName(food.name)
            if existingFoodsByName[name] == nil {
                existingFoodsByName[name] = food
            }
        }
        let changes = foods.compactMap { record -> (record: CommonFoodSeedRecord, food: FoodItem?)? in
            let existingFood = existingFoodsByName.removeValue(forKey: normalizedName(record.name))
            guard existingFood.map({ recordMatches(record, food: $0) }) != true else { return nil }
            return (record, existingFood)
        }
        guard changes.isEmpty == false else { return }

        try PersistenceReporter.persist(modelContext: modelContext, operation: "Reconcile common foods") {
            for change in changes {
                if let food = change.food {
                    apply(change.record, to: food)
                } else {
                    modelContext.insert(makeFoodItem(from: change.record))
                }
            }
        }
    }

    static func repairIfNeeded(modelContext: ModelContext, records: [CommonFoodSeedRecord]) throws {
        let commonFoods = try fetchCommonFoods(modelContext: modelContext)
        let recordsByName = Dictionary(uniqueKeysWithValues: records.map { ($0.name.lowercased(), $0) })
        let foodsNeedingRepair = commonFoods.filter { $0.secondaryNutrientBackfillState == .needsRepair }
        guard foodsNeedingRepair.isEmpty == false else { return }

        try PersistenceReporter.persist(modelContext: modelContext, operation: "Repair common food nutrients") {
            for food in foodsNeedingRepair {
                guard let record = recordsByName[food.name.lowercased()] else { continue }
                apply(record, to: food)
            }
        }
    }

    private static func fetchCommonFoods(modelContext: ModelContext) throws -> [FoodItem] {
        let commonSource = FoodSource.common.rawValue
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.source == commonSource })
        return try modelContext.fetch(descriptor)
    }

    private static func makeFoodItem(from record: CommonFoodSeedRecord) -> FoodItem {
        FoodItem(importedData: record.importedData, aliases: record.aliases)
    }

    static func makeFoodDraft(from record: CommonFoodSeedRecord) -> FoodDraft {
        FoodDraft(importedData: record.importedData, saveAsCustomFood: false)
    }

    private static func apply(_ record: CommonFoodSeedRecord, to food: FoodItem) {
        food.name = record.name
        food.servingDescription = record.servingDescription
        food.gramsPerServing = record.gramsPerServing
        food.caloriesPerServing = record.caloriesPerServing
        food.proteinPerServing = record.proteinPerServing
        food.fatPerServing = record.fatPerServing
        food.carbsPerServing = record.carbsPerServing
        food.saturatedFatPerServing = record.saturatedFatPerServing
        food.fiberPerServing = record.fiberPerServing
        food.sugarsPerServing = record.sugarsPerServing
        food.addedSugarsPerServing = record.addedSugarsPerServing
        food.sodiumPerServing = record.sodiumPerServing
        food.cholesterolPerServing = record.cholesterolPerServing
        food.secondaryNutrientBackfillState = .current
        food.updateSearchableText(with: record.aliases)
    }

    private static func recordMatches(_ record: CommonFoodSeedRecord, food: FoodItem) -> Bool {
        let seededFood = makeFoodItem(from: record)
        return food.name == seededFood.name
            && food.servingDescription == seededFood.servingDescription
            && food.gramsPerServing == seededFood.gramsPerServing
            && food.caloriesPerServing == seededFood.caloriesPerServing
            && food.proteinPerServing == seededFood.proteinPerServing
            && food.fatPerServing == seededFood.fatPerServing
            && food.carbsPerServing == seededFood.carbsPerServing
            && food.saturatedFatPerServing == seededFood.saturatedFatPerServing
            && food.fiberPerServing == seededFood.fiberPerServing
            && food.sugarsPerServing == seededFood.sugarsPerServing
            && food.addedSugarsPerServing == seededFood.addedSugarsPerServing
            && food.sodiumPerServing == seededFood.sodiumPerServing
            && food.cholesterolPerServing == seededFood.cholesterolPerServing
            && food.secondaryNutrientBackfillState == .current
            && food.searchableText == seededFood.searchableText
    }

    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

extension CommonFoodSeedRecord: FoodDraftImportedDataConvertible {
    var source: FoodSource { .common }
}
