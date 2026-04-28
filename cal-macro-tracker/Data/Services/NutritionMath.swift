import Foundation

struct LoggedFoodNutrients {
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double
    var saturatedFat: Double?
    var fiber: Double?
    var sugars: Double?
    var addedSugars: Double?
    var sodium: Double?
    var cholesterol: Double?

    static let zero = LoggedFoodNutrients(
        calories: 0,
        protein: 0,
        fat: 0,
        carbs: 0,
        saturatedFat: nil,
        fiber: nil,
        sugars: nil,
        addedSugars: nil,
        sodium: nil,
        cholesterol: nil
    )

}

struct NutritionMath {
    static func quantityMultiplier(mode: QuantityMode, amount: Double, gramsPerServing: Double?) -> Double? {
        guard amount.isFinite, amount > 0 else { return nil }

        switch mode {
        case .servings:
            return amount
        case .grams:
            guard let gramsPerServing, gramsPerServing.isFinite, gramsPerServing > 0 else { return nil }
            return amount / gramsPerServing
        }
    }

    static func consumedNutrients(for food: FoodDraft, mode: QuantityMode, amount: Double) -> LoggedFoodNutrients {
        guard let multiplier = quantityMultiplier(mode: mode, amount: amount, gramsPerServing: food.gramsPerServing) else {
            return .zero
        }

        return scaledNutrients(for: food, multiplier: multiplier)
    }
    private static func scaledNutrients(for food: FoodDraft, multiplier: Double) -> LoggedFoodNutrients {
        guard
            multiplier.isFinite,
            food.caloriesPerServing.isFinite,
            food.proteinPerServing.isFinite,
            food.fatPerServing.isFinite,
            food.carbsPerServing.isFinite
        else {
            return .zero
        }

        return LoggedFoodNutrients(
            calories: food.caloriesPerServing * multiplier,
            protein: food.proteinPerServing * multiplier,
            fat: food.fatPerServing * multiplier,
            carbs: food.carbsPerServing * multiplier,
            saturatedFat: scaled(food.saturatedFatPerServing, by: multiplier),
            fiber: scaled(food.fiberPerServing, by: multiplier),
            sugars: scaled(food.sugarsPerServing, by: multiplier),
            addedSugars: scaled(food.addedSugarsPerServing, by: multiplier),
            sodium: scaled(food.sodiumPerServing, by: multiplier),
            cholesterol: scaled(food.cholesterolPerServing, by: multiplier)
        )
    }

    private static func scaled(_ value: Double?, by multiplier: Double) -> Double? {
        guard let value else { return nil }
        guard value.isFinite else { return nil }
        return value * multiplier
    }
}
