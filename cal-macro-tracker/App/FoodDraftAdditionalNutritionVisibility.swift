struct FoodDraftAdditionalNutritionVisibility {
    let isExpanded: Bool
    let hasInvalidAdditionalNutritionValues: Bool
    let focusedField: FoodDraftField?

    var isVisible: Bool {
        isExpanded || requiresVisibility
    }

    var requiresVisibility: Bool {
        hasInvalidAdditionalNutritionValues || focusedField?.isAdditionalNutritionField == true
    }
}
