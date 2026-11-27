import Foundation
import SwiftData

/// Maps a suggested food to the server's generic match, then the on-device catalog.
struct MealPhotoMatcher {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Search phrases from most to least specific: "grilled chicken breast", then "chicken breast".
    static func queries(for name: String) -> [String] {
        let words = name.split(whereSeparator: \.isWhitespace).map(String.init)
        guard words.count > 1 else { return words }
        return (0..<words.count - 1).map { words[$0...].joined(separator: " ") }
    }

    func localMatch(for name: String) -> FoodDraft? {
        for query in Self.queries(for: name) {
            guard let candidates = try? FoodItemLocalSearch.fetchedCandidates(in: modelContext, matching: query),
                let food = FoodItemLocalSearch.rankedFoods(
                    candidates, matching: query, priorities: CommonFoodSeedLoader.staplePriorities
                ).first
            else { continue }
            return FoodDraft(foodItem: food, saveAsCustomFood: false)
        }
        return nil
    }

    func serverMatch(_ match: MealPhotoFoodMatch) -> FoodDraft? {
        guard match.source == "usdaFNDDS", match.fdcId > 0, !match.description.isEmpty else { return nil }
        let externalProductID = "usda-fndds:\(match.fdcId)"
        let repository = FoodItemRepository(modelContext: modelContext)
        if let cached = try? repository.fetchReusableFood(source: .searchLookup, externalProductID: externalProductID) {
            return FoodDraft(foodItem: cached, saveAsCustomFood: true)
        }
        let nutrients = match.per100g
        var draft = FoodDraft()
        draft.name = match.description
        draft.source = .searchLookup
        draft.externalProductID = externalProductID
        draft.sourceName = "USDA FoodData Central (FNDDS)"
        draft.sourceURL = "https://fdc.nal.usda.gov/food-details/\(match.fdcId)/nutrients"
        draft.servingDescription = "100 g"
        draft.gramsPerServing = 100
        draft.caloriesPerServing = nutrients.calories ?? 0
        draft.proteinPerServing = nutrients.protein ?? 0
        draft.carbsPerServing = nutrients.carbs ?? 0
        draft.fatPerServing = nutrients.fat ?? 0
        draft.saturatedFatPerServing = nutrients.saturatedFat
        draft.fiberPerServing = nutrients.fiber
        draft.sugarsPerServing = nutrients.sugars
        draft.sodiumPerServing = nutrients.sodium
        draft.cholesterolPerServing = nutrients.cholesterol
        draft.saveAsCustomFood = true
        return draft
    }
}
