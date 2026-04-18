import SwiftUI

struct FoodDraftEditorForm<QuantitySection: View, FooterSections: View>: View {
    @Binding var draft: FoodDraft
    @Binding var numericText: FoodDraftNumericText
    @Binding var errorMessage: String?
    let brandPrompt: String
    let gramsPrompt: String
    let focusedField: FocusState<FoodDraftField?>.Binding
    let trailingKeyboardFields: [FoodDraftField]
    let previewTotals: NutritionSnapshot?
    @ViewBuilder let quantitySection: () -> QuantitySection
    @ViewBuilder let footerSections: () -> FooterSections
    @State private var showsAdditionalNutrition = false

    init(
        draft: Binding<FoodDraft>,
        numericText: Binding<FoodDraftNumericText>,
        errorMessage: Binding<String?>,
        brandPrompt: String,
        gramsPrompt: String,
        focusedField: FocusState<FoodDraftField?>.Binding,
        trailingKeyboardFields: [FoodDraftField],
        previewTotals: NutritionSnapshot?,
        @ViewBuilder quantitySection: @escaping () -> QuantitySection,
        @ViewBuilder footerSections: @escaping () -> FooterSections
    ) {
        _draft = draft
        _numericText = numericText
        _errorMessage = errorMessage
        self.brandPrompt = brandPrompt
        self.gramsPrompt = gramsPrompt
        self.focusedField = focusedField
        self.trailingKeyboardFields = trailingKeyboardFields
        self.previewTotals = previewTotals
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
                showsAdditionalNutrition: $showsAdditionalNutrition,
                focusedField: focusedField
            )

            quantitySection()

            if let previewTotals {
                FoodDraftPreviewSection(totals: previewTotals)
            }

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

private struct FoodDraftPreviewSection: View {
    let totals: NutritionSnapshot

    var body: some View {
        Section("Preview") {
            previewRow(label: "Calories", value: totals.calories, suffix: "kcal")
            previewRow(label: "Protein", value: totals.protein, suffix: "g")
            previewRow(label: "Fat", value: totals.fat, suffix: "g")
            previewRow(label: "Carbs", value: totals.carbs, suffix: "g")
        }
    }

    private func previewRow(label: String, value: Double, suffix: String) -> some View {
        LabeledContent(label) {
            Text("\(value.roundedForDisplay) \(suffix)")
                .monospacedDigit()
        }
    }
}
