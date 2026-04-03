import Foundation

struct NutritionSnapshot: Hashable {
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double

    static let zero = NutritionSnapshot(calories: 0, protein: 0, fat: 0, carbs: 0)
}

struct NutritionMath {
    static func totals(for entries: [LogEntry]) -> NutritionSnapshot {
        entries.reduce(into: .zero) { partial, entry in
            partial.calories += entry.caloriesConsumed
            partial.protein += entry.proteinConsumed
            partial.fat += entry.fatConsumed
            partial.carbs += entry.carbsConsumed
        }
    }

    static func caloriesProgress(consumed: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(max(consumed / goal, 0), 1)
    }

    static func macroShare(snapshot: NutritionSnapshot) -> (protein: Double, carbs: Double, fat: Double) {
        let total = max(snapshot.protein + snapshot.carbs + snapshot.fat, 0)
        guard total > 0 else { return (0, 0, 0) }

        return (
            protein: snapshot.protein / total,
            carbs: snapshot.carbs / total,
            fat: snapshot.fat / total
        )
    }

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
