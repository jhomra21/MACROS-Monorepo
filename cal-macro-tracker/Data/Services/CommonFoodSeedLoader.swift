import Foundation
import SwiftData

struct CommonFoodSeedRecord: Decodable, Sendable {
    let sourceIdentifier: String
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

nonisolated struct CommonFoodSeedManifest: Decodable, Sendable {
    let version: String
    let source: String
    let sourceRelease: String
    let count: Int
    let generatedAt: String
    let staples: [String]?
}

enum CommonFoodSeedLoader {
    static let staplePriorities: [String: Int] = {
        guard
            let manifestURL = try? commonFoodSeedManifestURL(),
            let data = try? Data(contentsOf: manifestURL),
            let manifest = try? JSONDecoder().decode(CommonFoodSeedManifest.self, from: data)
        else { return [:] }

        return Dictionary(
            uniqueKeysWithValues: (manifest.staples ?? []).enumerated().map { ($0.element, $0.offset + 1) }
        )
    }()

    static func commonFoodSeedManifest() async throws -> CommonFoodSeedManifest {
        let url = try commonFoodSeedManifestURL()
        return try await commonFoodSeedManifest(from: url)
    }

    static func commonFoodSeedManifest(from url: URL) async throws -> CommonFoodSeedManifest {
        return try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CommonFoodSeedManifest.self, from: data)
        }.value
    }

    static func commonFoodSeedRecords() async throws -> [CommonFoodSeedRecord] {
        let url = try commonFoodSeedURL()
        return try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([CommonFoodSeedRecord].self, from: data)
        }.value
    }

    private static func commonFoodSeedManifestURL() throws -> URL {
        guard let url = Bundle.main.url(forResource: "common_foods_manifest", withExtension: "json") else {
            throw NSError(
                domain: "CommonFoodSeedLoader",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Missing common_foods_manifest.json resource."]
            )
        }
        return url
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

        var existingFoodsBySourceIdentifier: [String: FoodItem] = [:]
        var unidentifiedFoodsByName: [String: FoodItem] = [:]
        var unidentifiedFoodsBySourceDescription: [String: FoodItem] = [:]
        var ambiguousSourceDescriptions = Set<String>()
        let orderedExistingFoods = existingFoods.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        for food in orderedExistingFoods {
            if let sourceIdentifier = food.sourceIdentifier {
                if existingFoodsBySourceIdentifier[sourceIdentifier] == nil {
                    existingFoodsBySourceIdentifier[sourceIdentifier] = food
                }
            } else {
                let name = normalizedName(food.name)
                if unidentifiedFoodsByName[name] == nil {
                    unidentifiedFoodsByName[name] = food
                }
                let searchableValues = food.searchableText
                    .components(separatedBy: FoodItemLocalSearch.searchableValueSeparator)
                    .map { $0.components(separatedBy: FoodItemLocalSearch.searchableIndexSeparator).first ?? $0 }
                for value in searchableValues where normalizedName(value) != name {
                    let sourceDescription = normalizedName(value)
                    if let existingFood = unidentifiedFoodsBySourceDescription[sourceDescription],
                        existingFood.id != food.id
                    {
                        unidentifiedFoodsBySourceDescription.removeValue(forKey: sourceDescription)
                        ambiguousSourceDescriptions.insert(sourceDescription)
                    } else if ambiguousSourceDescriptions.contains(sourceDescription) == false {
                        unidentifiedFoodsBySourceDescription[sourceDescription] = food
                    }
                }
            }
        }
        var claimedFoodIDs = Set<UUID>()
        func claim(_ food: FoodItem?) -> FoodItem? {
            guard let food, claimedFoodIDs.insert(food.id).inserted else { return nil }
            return food
        }

        let changes = foods.compactMap { record -> (record: CommonFoodSeedRecord, food: FoodItem?)? in
            let sourceDescriptionFood = record.aliases.first.flatMap { alias -> FoodItem? in
                unidentifiedFoodsBySourceDescription.removeValue(forKey: normalizedName(alias))
            }
            if let sourceDescriptionFood {
                unidentifiedFoodsByName.removeValue(forKey: normalizedName(sourceDescriptionFood.name))
            }

            let existingFood =
                claim(existingFoodsBySourceIdentifier.removeValue(forKey: record.sourceIdentifier))
                ?? claim(
                    sourceDescriptionFood
                )
                ?? claim(unidentifiedFoodsByName.removeValue(forKey: normalizedName(record.name)))

            guard existingFood.map({ recordMatches(record, food: $0) }) != true else { return nil }
            return (record, existingFood)
        }
        let components = try modelContext.fetch(FetchDescriptor<MealComponent>())
        let referencedFoodIDs = Set(components.map(\.foodItemID))
        let staleFoods = existingFoods.filter {
            claimedFoodIDs.contains($0.id) == false
                && referencedFoodIDs.contains($0.id) == false
        }
        guard changes.isEmpty == false || staleFoods.isEmpty == false else { return }

        try PersistenceReporter.persist(modelContext: modelContext, operation: "Reconcile common foods") {
            for change in changes {
                if let food = change.food {
                    apply(change.record, to: food)
                } else {
                    modelContext.insert(makeFoodItem(from: change.record))
                }
            }
            for staleFood in staleFoods {
                modelContext.delete(staleFood)
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
        FoodItem(importedData: record.importedData, aliases: record.aliases, sourceIdentifier: record.sourceIdentifier)
    }

    static func makeFoodDraft(from record: CommonFoodSeedRecord) -> FoodDraft {
        FoodDraft(importedData: record.importedData, saveAsCustomFood: false)
    }

    private static func apply(_ record: CommonFoodSeedRecord, to food: FoodItem) {
        food.sourceIdentifier = record.sourceIdentifier
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
        return food.sourceIdentifier == seededFood.sourceIdentifier
            && food.name == seededFood.name
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
