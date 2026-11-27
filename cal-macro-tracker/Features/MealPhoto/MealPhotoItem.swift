import Foundation

/// One row on the review screen: a food the user will log, with the quantity the user confirmed.
struct MealPhotoItem: Identifiable, Equatable {
    enum Origin: Equatable {
        case suggested(MealPhotoSuggestedFood)
        case added
        case oil
    }

    let id: UUID
    let origin: Origin
    var food: FoodDraft?
    /// Grams when the food has a gram weight, otherwise servings. Nil until the user confirms a quantity.
    var amount: Double?

    var suggestion: MealPhotoSuggestedFood? {
        if case let .suggested(suggestion) = origin { return suggestion }
        return nil
    }

    var quantityMode: QuantityMode {
        food?.canLogByGrams == true ? .grams : .servings
    }

    var isReadyToLog: Bool {
        guard food != nil, let amount else { return false }
        return amount.isFinite && amount > 0
    }

    /// Grams eaten, when they are known. A servings-only food has no gram weight to convert with.
    var gramsEaten: Double? {
        guard let amount, amount > 0, let food else { return nil }
        switch quantityMode {
        case .grams: return amount
        case .servings: return food.gramsPerServing.map { $0 * amount }
        }
    }

    var nutrients: LoggedFoodNutrients {
        guard let food, let amount else { return .zero }
        return NutritionMath.consumedNutrients(for: food, mode: quantityMode, amount: amount)
    }

    var loggingAction: FoodDraftLoggingAction? {
        guard isReadyToLog, let food, let amount else { return nil }
        return food.loggingAction(initialDraft: food, quantityMode: quantityMode, quantityAmount: amount)
    }

    static func suggested(_ suggestion: MealPhotoSuggestedFood, food: FoodDraft?) -> MealPhotoItem {
        // Volume-only suggestions have no grams, so the user confirms the quantity.
        var item = MealPhotoItem(id: suggestion.id, origin: .suggested(suggestion), food: nil, amount: nil)
        if let food { item.replaceFood(with: food) }
        return item
    }

    static func added(food: FoodDraft) -> MealPhotoItem {
        var item = MealPhotoItem(id: UUID(), origin: .added, food: food, amount: nil)
        item.amount = item.quantityMode == .grams ? food.gramsPerServing : 1
        return item
    }

    /// A tablespoon of oil, matched like any other food. Falls back to a built-in olive oil when nothing matches.
    static func oil(matching food: FoodDraft?) -> MealPhotoItem {
        let food = food ?? oilFallback
        return MealPhotoItem(id: UUID(), origin: .oil, food: food, amount: food.canLogByGrams ? oilGrams : 1)
    }

    static let oilGrams = 14.0

    /// Replaces the matched food. Grams carry over to a food with a gram weight; servings never turn into grams.
    mutating func replaceFood(with newFood: FoodDraft) {
        let previousMode = quantityMode
        let carriedGrams = gramsEaten ?? suggestion?.grams
        food = newFood
        if quantityMode == .grams {
            amount = previousMode == .grams ? amount ?? carriedGrams : carriedGrams
        } else if previousMode == .grams {
            amount = nil
        }
    }

    // Same values as the bundled "Olive Oil" food (1 tablespoon).
    private static let oilFallback: FoodDraft = {
        var draft = FoodDraft()
        draft.name = "Olive oil"
        draft.servingDescription = "1 tbsp (14 g)"
        draft.gramsPerServing = oilGrams
        draft.caloriesPerServing = 126
        draft.fatPerServing = 14
        draft.saveAsCustomFood = false
        return draft
    }()
}
