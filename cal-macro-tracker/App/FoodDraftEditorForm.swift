import SwiftUI

struct FoodDraftEditorForm<QuantitySection: View, FooterSections: View>: View {
    @Binding var draft: FoodDraft
    @Binding var numericText: FoodDraftNumericText
    @Binding var errorMessage: String?
    let brandPrompt: String
    let gramsPrompt: String
    let nutritionPresentation: FoodDraftNutritionPresentation?
    let focusedField: FocusState<FoodDraftField?>.Binding
    let trailingKeyboardFields: [FoodDraftField]
    @ViewBuilder let quantitySection: () -> QuantitySection
    @ViewBuilder let footerSections: () -> FooterSections
    @State private var showsAdditionalNutrition = false

    init(
        draft: Binding<FoodDraft>,
        numericText: Binding<FoodDraftNumericText>,
        errorMessage: Binding<String?>,
        brandPrompt: String,
        gramsPrompt: String,
        nutritionPresentation: FoodDraftNutritionPresentation? = nil,
        focusedField: FocusState<FoodDraftField?>.Binding,
        trailingKeyboardFields: [FoodDraftField],
        @ViewBuilder quantitySection: @escaping () -> QuantitySection,
        @ViewBuilder footerSections: @escaping () -> FooterSections
    ) {
        _draft = draft
        _numericText = numericText
        _errorMessage = errorMessage
        self.brandPrompt = brandPrompt
        self.gramsPrompt = gramsPrompt
        self.nutritionPresentation = nutritionPresentation
        self.focusedField = focusedField
        self.trailingKeyboardFields = trailingKeyboardFields
        self.quantitySection = quantitySection
        self.footerSections = footerSections
        _showsAdditionalNutrition = State(initialValue: draft.wrappedValue.isMissingAllSecondaryNutrients == false)
    }

    private var keyboardFields: [FoodDraftField] {
        FoodDraftField.editorFormOrder(
            includingAdditionalNutrition: showsVisibleAdditionalNutrition,
            trailingFields: trailingKeyboardFields
        )
    }

    private var showsVisibleAdditionalNutrition: Bool {
        showsAdditionalNutrition
            || numericText.hasInvalidAdditionalNutritionValues
            || focusedField.wrappedValue?.isAdditionalNutritionField == true
    }

    var body: some View {
        Form {
            FoodDraftFormSections(
                draft: $draft,
                numericText: $numericText,
                brandPrompt: brandPrompt,
                gramsPrompt: gramsPrompt,
                nutritionPresentation: nutritionPresentation,
                showsAdditionalNutrition: $showsAdditionalNutrition,
                focusedField: focusedField
            )

            quantitySection()

            footerSections()
        }
        .scrollDismissesKeyboard(.interactively)
        .keyboardNavigationToolbar(focusedField: focusedField, fields: keyboardFields)
        .errorBanner(message: $errorMessage)
        .onChange(of: draft.isMissingAllSecondaryNutrients) { _, isMissingAllSecondaryNutrients in
            if isMissingAllSecondaryNutrients == false {
                showsAdditionalNutrition = true
            }
        }
    }
}
