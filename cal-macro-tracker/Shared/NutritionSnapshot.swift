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

struct SecondaryNutritionSnapshot: Hashable {
    var saturatedFat: Double?
    var fiber: Double?
    var sugars: Double?
    var addedSugars: Double?
    var sodium: Double?
    var cholesterol: Double?

    static let zero = SecondaryNutritionSnapshot(
        saturatedFat: nil,
        fiber: nil,
        sugars: nil,
        addedSugars: nil,
        sodium: nil,
        cholesterol: nil
    )

    static func totals(for entries: [LogEntry]) -> SecondaryNutritionSnapshot {
        entries.reduce(into: .zero) { partial, entry in
            partial.saturatedFat = summed(partial.saturatedFat, entry.saturatedFatConsumed)
            partial.fiber = summed(partial.fiber, entry.fiberConsumed)
            partial.sugars = summed(partial.sugars, entry.sugarsConsumed)
            partial.addedSugars = summed(partial.addedSugars, entry.addedSugarsConsumed)
            partial.sodium = summed(partial.sodium, entry.sodiumConsumed)
            partial.cholesterol = summed(partial.cholesterol, entry.cholesterolConsumed)
        }
    }

    private static func summed(_ currentTotal: Double?, _ nextValue: Double?) -> Double? {
        guard let nextValue else { return currentTotal }
        return (currentTotal ?? 0) + nextValue
    }
}
