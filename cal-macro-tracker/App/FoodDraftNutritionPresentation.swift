import SwiftUI

struct FoodDraftNutritionPresentation {
    let title: String
    let multiplier: Double
    private let maximumFractionDigits = 2

    func displayValue(from storedValue: String, emptyWhenZero: Bool) -> String {
        switch NumericText.state(for: storedValue) {
        case .empty, .invalid:
            return storedValue
        case let .valid(value):
            return NumericText.editingDisplay(
                for: roundedNutritionValue(value * multiplier),
                emptyWhenZero: emptyWhenZero
            )
        }
    }

    func storedValue(from presentedValue: String, emptyWhenZero: Bool) -> String {
        switch NumericText.state(for: presentedValue) {
        case .empty, .invalid:
            return presentedValue
        case let .valid(value):
            return NumericText.editingDisplay(
                for: value / multiplier,
                emptyWhenZero: emptyWhenZero
            )
        }
    }

    private func roundedNutritionValue(_ value: Double) -> Double {
        let factor = pow(10.0, Double(maximumFractionDigits))
        return (value * factor).rounded() / factor
    }
}

struct FoodDraftNutrientTextConfiguration {
    let keyPath: WritableKeyPath<FoodDraftNumericText, String>
    let emptyWhenZero: Bool
}

extension FoodDraftField {
    var nutrientTextConfiguration: FoodDraftNutrientTextConfiguration? {
        switch self {
        case .calories:
            FoodDraftNutrientTextConfiguration(keyPath: \.calories, emptyWhenZero: true)
        case .protein:
            FoodDraftNutrientTextConfiguration(keyPath: \.protein, emptyWhenZero: true)
        case .fat:
            FoodDraftNutrientTextConfiguration(keyPath: \.fat, emptyWhenZero: true)
        case .carbs:
            FoodDraftNutrientTextConfiguration(keyPath: \.carbs, emptyWhenZero: true)
        case .saturatedFat:
            FoodDraftNutrientTextConfiguration(keyPath: \.saturatedFat, emptyWhenZero: false)
        case .fiber:
            FoodDraftNutrientTextConfiguration(keyPath: \.fiber, emptyWhenZero: false)
        case .sugars:
            FoodDraftNutrientTextConfiguration(keyPath: \.sugars, emptyWhenZero: false)
        case .addedSugars:
            FoodDraftNutrientTextConfiguration(keyPath: \.addedSugars, emptyWhenZero: false)
        case .sodium:
            FoodDraftNutrientTextConfiguration(keyPath: \.sodium, emptyWhenZero: false)
        case .cholesterol:
            FoodDraftNutrientTextConfiguration(keyPath: \.cholesterol, emptyWhenZero: false)
        case .name, .brand, .servingDescription, .gramsPerServing:
            nil
        }
    }
}
