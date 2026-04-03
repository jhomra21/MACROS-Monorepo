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
            throw NSError(domain: "CommonFoodSeedLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing common_foods.json resource."])
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
                let food = FoodItem(
                    name: item.name,
                    source: .common,
                    servingDescription: item.servingDescription,
                    gramsPerServing: item.gramsPerServing,
                    caloriesPerServing: item.caloriesPerServing,
                    proteinPerServing: item.proteinPerServing,
                    fatPerServing: item.fatPerServing,
                    carbsPerServing: item.carbsPerServing,
                    aliases: item.aliases
                )
                modelContext.insert(food)
            }
        }
    }
}
