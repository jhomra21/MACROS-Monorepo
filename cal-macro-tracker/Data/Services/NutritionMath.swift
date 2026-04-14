import Foundation

struct NutritionMath {
    static func consumedNutrition(for food: FoodDraft, mode: QuantityMode, amount: Double) -> NutritionSnapshot {
        guard amount > 0 else { return .zero }

        switch mode {
        case .servings:
            return NutritionSnapshot(
                calories: food.caloriesPerServing * amount,
                protein: food.proteinPerServing * amount,
                fat: food.fatPerServing * amount,
                carbs: food.carbsPerServing * amount
            )
        case .grams:
            guard let gramsPerServing = food.gramsPerServing, gramsPerServing > 0 else {
                return .zero
            }

            let multiplier = amount / gramsPerServing
            return NutritionSnapshot(
                calories: food.caloriesPerServing * multiplier,
                protein: food.proteinPerServing * multiplier,
                fat: food.fatPerServing * multiplier,
                carbs: food.carbsPerServing * multiplier
            )
        }
    }
}
