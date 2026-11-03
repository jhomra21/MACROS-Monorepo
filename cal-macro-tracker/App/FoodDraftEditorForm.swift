import SwiftUI

struct FoodDraftEditorConfiguration {
    let brandPrompt: String
    let gramsPrompt: String
    let nutritionPresentation: FoodDraftNutritionPresentation?
    let trailingKeyboardFields: [FoodDraftField]

    init(
        brandPrompt: String,
        gramsPrompt: String,
        nutritionPresentation: FoodDraftNutritionPresentation? = nil,
        trailingKeyboardFields: [FoodDraftField] = []
    ) {
        self.brandPrompt = brandPrompt
        self.gramsPrompt = gramsPrompt
        self.nutritionPresentation = nutritionPresentation
        self.trailingKeyboardFields = trailingKeyboardFields
    }
}

struct FoodDraftEditorForm<QuantitySection: View, FooterSections: View>: View {
    @Binding var draft: FoodDraft
    @Binding var numericText: FoodDraftNumericText
    @Binding var errorMessage: String?
    let configuration: FoodDraftEditorConfiguration
    let focusedField: FocusState<FoodDraftField?>.Binding
    let rowBackground: Color?
    let leadingSections: AnyView?
    let scrollsToFocusedField: Bool
    @ViewBuilder let quantitySection: () -> QuantitySection
    @ViewBuilder let footerSections: () -> FooterSections
    @State private var showsAdditionalNutrition = false
    @State private var requestedFocus: FoodDraftField?

    init(
        draft: Binding<FoodDraft>,
        numericText: Binding<FoodDraftNumericText>,
        errorMessage: Binding<String?>,
        configuration: FoodDraftEditorConfiguration,
        focusedField: FocusState<FoodDraftField?>.Binding,
        rowBackground: Color? = nil,
        leadingSections: AnyView? = nil,
        scrollsToFocusedField: Bool = false,
        @ViewBuilder quantitySection: @escaping () -> QuantitySection,
        @ViewBuilder footerSections: @escaping () -> FooterSections
    ) {
        _draft = draft
        _numericText = numericText
        _errorMessage = errorMessage
        self.configuration = configuration
        self.focusedField = focusedField
        self.rowBackground = rowBackground
        self.leadingSections = leadingSections
        self.scrollsToFocusedField = scrollsToFocusedField
        self.quantitySection = quantitySection
        self.footerSections = footerSections
        _showsAdditionalNutrition = State(initialValue: draft.wrappedValue.isMissingAllSecondaryNutrients == false)
    }

    private var keyboardFields: [FoodDraftField] {
        FoodDraftField.editorFormOrder(
            includingAdditionalNutrition: showsVisibleAdditionalNutrition,
            trailingFields: configuration.trailingKeyboardFields
        )
    }

    private var showsVisibleAdditionalNutrition: Bool {
        FoodDraftAdditionalNutritionVisibility(
            isExpanded: showsAdditionalNutrition,
            hasInvalidAdditionalNutritionValues: numericText.hasInvalidAdditionalNutritionValues,
            focusedField: focusedField.wrappedValue
        )
        .isVisible
    }

    var body: some View {
        if scrollsToFocusedField {
            ScrollViewReader { proxy in
                form { field in
                    requestedFocus = field
                    proxy.scrollTo(field, anchor: .center)
                    focusedField.wrappedValue = field
                }
                .onChange(of: focusedField.wrappedValue) { _, field in
                    if field == requestedFocus { requestedFocus = nil }
                }
            }
        } else {
            form()
        }
    }

    private func form(onFocusRequest: ((FoodDraftField) -> Void)? = nil) -> some View {
        Form {
            leadingSections
                .listRowBackground(rowBackground)
            FoodDraftFormSections(
                draft: $draft,
                numericText: $numericText,
                configuration: configuration,
                showsAdditionalNutrition: $showsAdditionalNutrition,
                focusedField: focusedField,
                onFieldAppear: focusAppearedField
            )
            .listRowBackground(rowBackground)

            quantitySection()
                .listRowBackground(rowBackground)

            footerSections()
                .listRowBackground(rowBackground)
        }
        .scrollDismissesKeyboard(.interactively)
        .keyboardNavigationToolbar(
            focusedField: focusedField,
            fields: keyboardFields,
            onFocusRequest: onFocusRequest
        )
        .errorBanner(message: $errorMessage)
        .onChange(of: draft.isMissingAllSecondaryNutrients) { _, isMissingAllSecondaryNutrients in
            if isMissingAllSecondaryNutrients == false {
                showsAdditionalNutrition = true
            }
        }
    }

    private func focusAppearedField(_ field: FoodDraftField) {
        // Form realizes offscreen rows after scrollTo; focus them when they actually appear.
        guard requestedFocus == field else { return }
        focusedField.wrappedValue = field
        requestedFocus = nil
    }
}
