import Foundation

struct PerServingNutritionValues: Hashable {
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let saturatedFat: Double?
    let fiber: Double?
    let sugars: Double?
    let addedSugars: Double?
    let sodium: Double?
    let cholesterol: Double?

    static let zero = PerServingNutritionValues(
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

protocol PerServingNutritionValueConvertible {
    var caloriesPerServing: Double { get }
    var proteinPerServing: Double { get }
    var fatPerServing: Double { get }
    var carbsPerServing: Double { get }
    var saturatedFatPerServing: Double? { get }
    var fiberPerServing: Double? { get }
    var sugarsPerServing: Double? { get }
    var addedSugarsPerServing: Double? { get }
    var sodiumPerServing: Double? { get }
    var cholesterolPerServing: Double? { get }
}

extension PerServingNutritionValueConvertible {
    var perServingNutritionValues: PerServingNutritionValues {
        PerServingNutritionValues(
            calories: caloriesPerServing,
            protein: proteinPerServing,
            fat: fatPerServing,
            carbs: carbsPerServing,
            saturatedFat: saturatedFatPerServing,
            fiber: fiberPerServing,
            sugars: sugarsPerServing,
            addedSugars: addedSugarsPerServing,
            sodium: sodiumPerServing,
            cholesterol: cholesterolPerServing
        )
    }
}

extension FoodDraft: PerServingNutritionValueConvertible {}
extension FoodDraftImportedData: PerServingNutritionValueConvertible {}
extension FoodItem: PerServingNutritionValueConvertible {}
extension LogEntry: PerServingNutritionValueConvertible {}
