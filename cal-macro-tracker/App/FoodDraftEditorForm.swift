import SwiftUI

struct FoodDraftEditorForm<QuantitySection: View, FooterSections: View>: View {
    @Binding var draft: FoodDraft
    @Binding var numericText: FoodDraftNumericText
    @Binding var errorMessage: String?
    let brandPrompt: String
    let gramsPrompt: String
    let focusedField: FocusState<FoodDraftField?>.Binding
    let keyboardFields: [FoodDraftField]
    let previewTotals: NutritionSnapshot?
    @ViewBuilder let quantitySection: () -> QuantitySection
    @ViewBuilder let footerSections: () -> FooterSections

    var body: some View {
        Form {
            FoodDraftFormSections(
                draft: $draft,
                numericText: $numericText,
                brandPrompt: brandPrompt,
                gramsPrompt: gramsPrompt,
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
