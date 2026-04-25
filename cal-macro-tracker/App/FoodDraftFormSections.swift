import SwiftUI

enum FoodDraftField: Hashable {
    case name
    case brand
    case servingDescription
    case gramsPerServing
    case calories
    case protein
    case fat
    case carbs
    case saturatedFat
    case fiber
    case sugars
    case addedSugars
    case sodium
    case cholesterol

    static let baseFormOrder: [FoodDraftField] = [
        .name,
        .brand,
        .servingDescription,
        .gramsPerServing,
        .calories,
        .protein,
        .fat,
        .carbs
    ]

    static let additionalNutritionFields: [FoodDraftField] = [
        .saturatedFat,
        .fiber,
        .sugars,
        .addedSugars,
        .sodium,
        .cholesterol
    ]

    static func editorFormOrder(
        includingAdditionalNutrition: Bool,
        trailingFields: [FoodDraftField] = []
    ) -> [FoodDraftField] {
        baseFormOrder + (includingAdditionalNutrition ? additionalNutritionFields : []) + trailingFields
    }

    var isAdditionalNutritionField: Bool {
        Self.additionalNutritionFields.contains(self)
    }
}

@MainActor
struct FoodDraftNumericText: Equatable {
    var gramsPerServing: String
    var calories: String
    var protein: String
    var fat: String
    var carbs: String
    var saturatedFat: String
    var fiber: String
    var sugars: String
    var addedSugars: String
    var sodium: String
    var cholesterol: String

    init(draft: FoodDraft) {
        gramsPerServing = NumericText.editingDisplay(for: draft.gramsPerServing)
        calories = NumericText.editingDisplay(for: draft.caloriesPerServing, emptyWhenZero: true)
        protein = NumericText.editingDisplay(for: draft.proteinPerServing, emptyWhenZero: true)
        fat = NumericText.editingDisplay(for: draft.fatPerServing, emptyWhenZero: true)
        carbs = NumericText.editingDisplay(for: draft.carbsPerServing, emptyWhenZero: true)
        saturatedFat = NumericText.editingDisplay(for: draft.saturatedFatPerServing)
        fiber = NumericText.editingDisplay(for: draft.fiberPerServing)
        sugars = NumericText.editingDisplay(for: draft.sugarsPerServing)
        addedSugars = NumericText.editingDisplay(for: draft.addedSugarsPerServing)
        sodium = NumericText.editingDisplay(for: draft.sodiumPerServing)
        cholesterol = NumericText.editingDisplay(for: draft.cholesterolPerServing)
    }

    var hasInvalidValues: Bool {
        [gramsPerServing, calories, protein, fat, carbs, saturatedFat, fiber, sugars, addedSugars, sodium, cholesterol]
            .contains { NumericText.state(for: $0).isInvalid }
    }

    var hasInvalidAdditionalNutritionValues: Bool {
        [saturatedFat, fiber, sugars, addedSugars, sodium, cholesterol]
            .contains { NumericText.state(for: $0).isInvalid }
    }

    func editingDraft(from draft: FoodDraft) -> FoodDraft {
        var editingDraft = draft
        editingDraft.gramsPerServing = optionalValue(from: gramsPerServing)
        editingDraft.caloriesPerServing = numericValue(from: calories)
        editingDraft.proteinPerServing = numericValue(from: protein)
        editingDraft.fatPerServing = numericValue(from: fat)
        editingDraft.carbsPerServing = numericValue(from: carbs)
        editingDraft.saturatedFatPerServing = optionalValue(from: saturatedFat)
        editingDraft.fiberPerServing = optionalValue(from: fiber)
        editingDraft.sugarsPerServing = optionalValue(from: sugars)
        editingDraft.addedSugarsPerServing = optionalValue(from: addedSugars)
        editingDraft.sodiumPerServing = optionalValue(from: sodium)
        editingDraft.cholesterolPerServing = optionalValue(from: cholesterol)
        return editingDraft
    }

    func finalizedDraft(from draft: FoodDraft) -> FoodDraft? {
        guard !hasInvalidValues else { return nil }
        return editingDraft(from: draft)
    }

    private func optionalValue(from text: String) -> Double? {
        switch NumericText.state(for: text) {
        case .empty, .invalid:
            return nil
        case let .valid(value):
            return value
        }
    }

    private func numericValue(from text: String) -> Double {
        switch NumericText.state(for: text) {
        case .empty, .invalid:
            return 0
        case let .valid(value):
            return value
        }
    }
}

struct FoodDraftFormSections: View {
    @Binding var draft: FoodDraft
    let configuration: FoodDraftEditorConfiguration
    let focusedField: FocusState<FoodDraftField?>.Binding
    @Binding var showsAdditionalNutrition: Bool
    @Binding private var numericText: FoodDraftNumericText
    @State private var nutrientEditingBridge = FoodDraftNutrientEditingBridge()

    init(
        draft: Binding<FoodDraft>,
        numericText: Binding<FoodDraftNumericText>,
        configuration: FoodDraftEditorConfiguration,
        showsAdditionalNutrition: Binding<Bool>,
        focusedField: FocusState<FoodDraftField?>.Binding
    ) {
        _draft = draft
        _numericText = numericText
        self.configuration = configuration
        _showsAdditionalNutrition = showsAdditionalNutrition
        self.focusedField = focusedField
    }

    var body: some View {
        Group {
            Section("Food") {
                TextField("Name", text: $draft.name)
                    .focused(focusedField, equals: .name)
                TextField(configuration.brandPrompt, text: $draft.brand)
                    .focused(focusedField, equals: .brand)
                TextField("Serving description", text: $draft.servingDescription)
                    .focused(focusedField, equals: .servingDescription)
                AppNumericTextField(
                    configuration.gramsPrompt,
                    text: numericBinding(\.gramsPerServing),
                    focusedField: focusedField,
                    field: .gramsPerServing
                )
            }

            Section(nutritionSectionTitle) {
                nutrientField(title: "Calories", suffix: "kcal", field: .calories, text: nutrientBinding(for: .calories))
                nutrientField(title: "Protein", suffix: "g", field: .protein, text: nutrientBinding(for: .protein))
                nutrientField(title: "Fat", suffix: "g", field: .fat, text: nutrientBinding(for: .fat))
                nutrientField(title: "Carbs", suffix: "g", field: .carbs, text: nutrientBinding(for: .carbs))
                additionalNutritionToggle

                if showsVisibleAdditionalNutrition {
                    nutrientField(
                        title: "Saturated Fat",
                        suffix: "g",
                        field: .saturatedFat,
                        text: nutrientBinding(for: .saturatedFat)
                    )
                    nutrientField(title: "Fiber", suffix: "g", field: .fiber, text: nutrientBinding(for: .fiber))
                    nutrientField(title: "Sugars", suffix: "g", field: .sugars, text: nutrientBinding(for: .sugars))
                    nutrientField(
                        title: "Added Sugars",
                        suffix: "g",
                        field: .addedSugars,
                        text: nutrientBinding(for: .addedSugars)
                    )
                    nutrientField(title: "Sodium", suffix: "mg", field: .sodium, text: nutrientBinding(for: .sodium))
                    nutrientField(
                        title: "Cholesterol",
                        suffix: "mg",
                        field: .cholesterol,
                        text: nutrientBinding(for: .cholesterol)
                    )
                }
            }
        }
        .onChange(of: focusedField.wrappedValue) { _, focusedField in
            nutrientEditingBridge.syncPresentedValues(with: focusedField)
        }
        .onChange(of: configuration.nutritionPresentation?.multiplier) { _, _ in
            nutrientEditingBridge.invalidatePresentedValues()
        }
    }

    private var additionalNutritionToggle: some View {
        Button {
            if showsVisibleAdditionalNutrition {
                guard requiresAdditionalNutritionVisibility == false else { return }
                showsAdditionalNutrition = false
            } else {
                showsAdditionalNutrition = true
            }
        } label: {
            HStack(spacing: 12) {
                Text(showsVisibleAdditionalNutrition ? "Show less" : "Show more")
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: showsVisibleAdditionalNutrition ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(requiresAdditionalNutritionVisibility && showsVisibleAdditionalNutrition)
    }

    private func nutrientField(title: String, suffix: String, field: FoodDraftField, text: Binding<String>) -> some View {
        NutrientInputField(
            title: title,
            suffix: suffix,
            text: text,
            focusedField: focusedField,
            field: field
        )
    }

    private func numericBinding(_ keyPath: WritableKeyPath<FoodDraftNumericText, String>) -> Binding<String> {
        Binding(
            get: { numericText[keyPath: keyPath] },
            set: { newValue in
                numericText[keyPath: keyPath] = newValue
                draft = numericText.editingDraft(from: draft)
            }
        )
    }

    private func nutrientBinding(for field: FoodDraftField) -> Binding<String> {
        guard let configuration = field.nutrientTextConfiguration else {
            assertionFailure("Unsupported nutrient field binding.")
            return .constant("")
        }

        return Binding(
            get: {
                nutrientEditingBridge.displayedText(
                    for: field,
                    configuration: configuration,
                    numericText: numericText,
                    nutritionPresentation: self.configuration.nutritionPresentation,
                    focusedField: focusedField.wrappedValue
                )
            },
            set: { newValue in
                nutrientEditingBridge.update(
                    newValue,
                    for: field,
                    configuration: configuration,
                    numericText: &numericText,
                    draft: &draft,
                    nutritionPresentation: self.configuration.nutritionPresentation
                )
            }
        )
    }

    private var nutritionSectionTitle: String { configuration.nutritionPresentation?.title ?? "Nutrition per serving" }

    private var showsVisibleAdditionalNutrition: Bool { showsAdditionalNutrition || requiresAdditionalNutritionVisibility }

    private var requiresAdditionalNutritionVisibility: Bool {
        numericText.hasInvalidAdditionalNutritionValues
            || focusedField.wrappedValue?.isAdditionalNutritionField == true
    }
}
