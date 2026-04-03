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
}

@MainActor
struct FoodDraftNumericText: Equatable {
    var gramsPerServing: String
    var calories: String
    var protein: String
    var fat: String
    var carbs: String

    init(draft: FoodDraft) {
        gramsPerServing = NumericText.editingDisplay(for: draft.gramsPerServing)
        calories = NumericText.editingDisplay(for: draft.caloriesPerServing, emptyWhenZero: true)
        protein = NumericText.editingDisplay(for: draft.proteinPerServing, emptyWhenZero: true)
        fat = NumericText.editingDisplay(for: draft.fatPerServing, emptyWhenZero: true)
        carbs = NumericText.editingDisplay(for: draft.carbsPerServing, emptyWhenZero: true)
    }

    var hasInvalidValues: Bool {
        [gramsPerServing, calories, protein, fat, carbs]
            .contains { NumericText.state(for: $0).isInvalid }
    }

    func editingDraft(from draft: FoodDraft) -> FoodDraft {
        var editingDraft = draft
        editingDraft.gramsPerServing = optionalValue(from: gramsPerServing)
        editingDraft.caloriesPerServing = numericValue(from: calories)
        editingDraft.proteinPerServing = numericValue(from: protein)
        editingDraft.fatPerServing = numericValue(from: fat)
        editingDraft.carbsPerServing = numericValue(from: carbs)
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
    let brandPrompt: String
    let gramsPrompt: String
    let focusedField: FocusState<FoodDraftField?>.Binding

    @Binding private var numericText: FoodDraftNumericText

    init(
        draft: Binding<FoodDraft>,
        numericText: Binding<FoodDraftNumericText>,
        brandPrompt: String,
        gramsPrompt: String,
        focusedField: FocusState<FoodDraftField?>.Binding
    ) {
        _draft = draft
        _numericText = numericText
        self.brandPrompt = brandPrompt
        self.gramsPrompt = gramsPrompt
        self.focusedField = focusedField
    }

    var body: some View {
        Group {
            Section("Food") {
                TextField("Name", text: $draft.name)
                    .focused(focusedField, equals: .name)
                TextField(brandPrompt, text: $draft.brand)
                    .focused(focusedField, equals: .brand)
                TextField("Serving description", text: $draft.servingDescription)
                    .focused(focusedField, equals: .servingDescription)
                TextField(gramsPrompt, text: numericBinding(\.gramsPerServing))
                    .focused(focusedField, equals: .gramsPerServing)
                    .numericKeyboard()
            }

            Section("Nutrition per serving") {
                nutrientField(title: "Calories", suffix: "kcal", field: .calories, text: numericBinding(\.calories))
                nutrientField(title: "Protein", suffix: "g", field: .protein, text: numericBinding(\.protein))
                nutrientField(title: "Fat", suffix: "g", field: .fat, text: numericBinding(\.fat))
                nutrientField(title: "Carbs", suffix: "g", field: .carbs, text: numericBinding(\.carbs))
            }
        }
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
}
