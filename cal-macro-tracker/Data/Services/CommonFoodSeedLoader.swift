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
        let commonSource = FoodSource.common.rawValue
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.source == commonSource })
        let existing = try modelContext.fetchCount(descriptor)
        guard existing == 0 else { return }

        let foods: [CommonFoodSeedRecord]
        if let records {
            foods = records
        } else {
            let url = try commonFoodSeedURL()
            let data = try Data(contentsOf: url)
            foods = try JSONDecoder().decode([CommonFoodSeedRecord].self, from: data)
        }

        try PersistenceReporter.persist(modelContext: modelContext, operation: "Seed common foods") {
            foods.forEach { item in
                let food = makeFoodItem(from: item)
                modelContext.insert(food)
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
}

extension CommonFoodSeedRecord: FoodDraftImportedDataConvertible {
    var source: FoodSource { .common }
}
