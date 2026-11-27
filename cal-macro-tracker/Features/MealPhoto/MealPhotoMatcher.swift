import Foundation
import SwiftData

/// Maps a suggested food name to a food in MACROS: the on-device catalog first, then the existing remote search.
/// A remote food that needs nutrient review is left unmatched so the user picks and reviews it explicitly.
struct MealPhotoMatcher {
    typealias RemoteSearch = @Sendable (String) async throws -> RemoteSearchResult?

    let modelContext: ModelContext
    let remoteSearch: RemoteSearch

    init(modelContext: ModelContext, remoteSearch: @escaping RemoteSearch = Self.searchRemote) {
        self.modelContext = modelContext
        self.remoteSearch = remoteSearch
    }

    static let searchRemote: RemoteSearch = { name in
        try await FoodSearchClient().searchFoods(query: name).results.first
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

    func remoteMatch(for name: String) async -> FoodDraft? {
        guard let result = try? await remoteSearch(name), result.requiredReviewNutrients.isEmpty else { return nil }
        let repository = FoodItemRepository(modelContext: modelContext)
        if let cached = try? result.cachedFood(using: repository) {
            return FoodDraft(foodItem: cached, saveAsCustomFood: true)
        }
        var draft = result.makeDraft()
        draft.saveAsCustomFood = true
        return draft
    }
}
