import Foundation

struct NutritionSnapshot: Hashable {
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double

    static let zero = NutritionSnapshot(calories: 0, protein: 0, fat: 0, carbs: 0)

    static func totals(for entries: [LogEntry]) -> NutritionSnapshot {
        entries.reduce(into: .zero) { partial, entry in
            partial.calories += entry.caloriesConsumed
            partial.protein += entry.proteinConsumed
            partial.fat += entry.fatConsumed
            partial.carbs += entry.carbsConsumed
        }
    }
}
