import SwiftUI

@MainActor
struct FoodDraftNutrientEditingBridge {
    private var presentedValues: [FoodDraftField: String] = [:]

    func displayedText(
        for field: FoodDraftField,
        configuration: FoodDraftNutrientTextConfiguration,
        numericText: FoodDraftNumericText,
        nutritionPresentation: FoodDraftNutritionPresentation?,
        focusedField: FoodDraftField?
    ) -> String {
        if focusedField == field, let presentedValue = presentedValues[field] {
            return presentedValue
        }

        let storedValue = numericText[keyPath: configuration.keyPath]
        guard let nutritionPresentation else { return storedValue }
        return nutritionPresentation.displayValue(
            from: storedValue,
            emptyWhenZero: configuration.emptyWhenZero
        )
    }

    mutating func update(
        _ newValue: String,
        for field: FoodDraftField,
        configuration: FoodDraftNutrientTextConfiguration,
        numericText: inout FoodDraftNumericText,
        draft: inout FoodDraft,
        nutritionPresentation: FoodDraftNutritionPresentation?
    ) {
        presentedValues[field] = newValue
        numericText[keyPath: configuration.keyPath] =
            nutritionPresentation?.storedValue(from: newValue, emptyWhenZero: configuration.emptyWhenZero) ?? newValue
        draft = numericText.editingDraft(from: draft)
    }

    mutating func syncPresentedValues(with focusedField: FoodDraftField?) {
        guard let focusedField else {
            presentedValues.removeAll()
            return
        }

        presentedValues = presentedValues.filter { $0.key == focusedField }
    }

    mutating func invalidatePresentedValues() {
        presentedValues.removeAll()
    }
}
