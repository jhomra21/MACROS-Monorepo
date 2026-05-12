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

        return scaledNutrients(for: food.perServingNutritionValues, multiplier: multiplier)
    }

    static func consumedNutrients(for food: FoodItem, mode: QuantityMode, amount: Double) -> LoggedFoodNutrients {
        guard let multiplier = quantityMultiplier(mode: mode, amount: amount, gramsPerServing: food.gramsPerServing) else {
            return .zero
        }

        return scaledNutrients(for: food.perServingNutritionValues, multiplier: multiplier)
    }

    static func scaledNutrients(for nutrients: LoggedFoodNutrients, multiplier: Double) -> LoggedFoodNutrients {
        guard
            multiplier.isFinite,
            nutrients.calories.isFinite,
            nutrients.protein.isFinite,
            nutrients.fat.isFinite,
            nutrients.carbs.isFinite
        else {
            return .zero
        }

        return LoggedFoodNutrients(
            calories: nutrients.calories * multiplier,
            protein: nutrients.protein * multiplier,
            fat: nutrients.fat * multiplier,
            carbs: nutrients.carbs * multiplier,
            saturatedFat: scaled(nutrients.saturatedFat, by: multiplier),
            fiber: scaled(nutrients.fiber, by: multiplier),
            sugars: scaled(nutrients.sugars, by: multiplier),
            addedSugars: scaled(nutrients.addedSugars, by: multiplier),
            sodium: scaled(nutrients.sodium, by: multiplier),
            cholesterol: scaled(nutrients.cholesterol, by: multiplier)
        )
    }

    static func summedNutrients(_ nutrients: [LoggedFoodNutrients]) -> LoggedFoodNutrients {
        var calories = 0.0
        var protein = 0.0
        var fat = 0.0
        var carbs = 0.0
        var saturatedFat: Double?
        var fiber: Double?
        var sugars: Double?
        var addedSugars: Double?
        var sodium: Double?
        var cholesterol: Double?

        for nutrient in nutrients {
            calories += nutrient.calories
            protein += nutrient.protein
            fat += nutrient.fat
            carbs += nutrient.carbs
            saturatedFat = summedOptional(saturatedFat, nutrient.saturatedFat)
            fiber = summedOptional(fiber, nutrient.fiber)
            sugars = summedOptional(sugars, nutrient.sugars)
            addedSugars = summedOptional(addedSugars, nutrient.addedSugars)
            sodium = summedOptional(sodium, nutrient.sodium)
            cholesterol = summedOptional(cholesterol, nutrient.cholesterol)
        }

        return LoggedFoodNutrients(
            calories: calories,
            protein: protein,
            fat: fat,
            carbs: carbs,
            saturatedFat: saturatedFat,
            fiber: fiber,
            sugars: sugars,
            addedSugars: addedSugars,
            sodium: sodium,
            cholesterol: cholesterol
        )
    }

    private static func scaledNutrients(for nutrition: PerServingNutritionValues, multiplier: Double) -> LoggedFoodNutrients {
        scaledNutrients(
            for: LoggedFoodNutrients(
                calories: nutrition.calories,
                protein: nutrition.protein,
                fat: nutrition.fat,
                carbs: nutrition.carbs,
                saturatedFat: nutrition.saturatedFat,
                fiber: nutrition.fiber,
                sugars: nutrition.sugars,
                addedSugars: nutrition.addedSugars,
                sodium: nutrition.sodium,
                cholesterol: nutrition.cholesterol
            ),
            multiplier: multiplier
        )
    }

    private static func scaled(_ value: Double?, by multiplier: Double) -> Double? {
        guard let value else { return nil }
        guard value.isFinite else { return nil }
        return value * multiplier
    }

    private static func summedOptional(_ existing: Double?, _ next: Double?) -> Double? {
        guard let next, next.isFinite else { return existing }
        return (existing ?? 0) + next
    }
}
