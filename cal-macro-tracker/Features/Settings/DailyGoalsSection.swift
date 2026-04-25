import SwiftData
import SwiftUI

enum DailyGoalsField: Hashable {
    case calories
    case protein
    case fat
    case carbs

    static let formOrder: [DailyGoalsField] = [
        .calories,
        .protein,
        .fat,
        .carbs
    ]
}

private struct DailyGoalsNumericText: Equatable {
    var calories: String
    var protein: String
    var fat: String
    var carbs: String

    init(goals: DailyGoals) {
        calories = NumericText.editingDisplay(for: goals.calorieGoal)
        protein = NumericText.editingDisplay(for: goals.proteinGoalGrams)
        fat = NumericText.editingDisplay(for: goals.fatGoalGrams)
        carbs = NumericText.editingDisplay(for: goals.carbGoalGrams)
    }

    var hasInvalidValues: Bool {
        [calories, protein, fat, carbs]
            .contains { NumericText.state(for: $0).isInvalid }
    }

    var finalizedDraft: DailyGoalsDraft? {
        guard !hasInvalidValues else { return nil }
        var draft = DailyGoalsDraft()
        draft.calorieGoal = numericValue(from: calories)
        draft.proteinGoalGrams = numericValue(from: protein)
        draft.fatGoalGrams = numericValue(from: fat)
        draft.carbGoalGrams = numericValue(from: carbs)
        return draft.isValid ? draft : nil
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

private struct DailyGoalsSection: View {
    @Binding var numericText: DailyGoalsNumericText
    let focusedField: FocusState<DailyGoalsField?>.Binding

    var body: some View {
        Section("Daily Goals") {
            NutrientInputField(
                title: "Calories",
                suffix: "kcal",
                text: $numericText.calories,
                focusedField: focusedField,
                field: .calories
            )
            NutrientInputField(
                title: "Protein",
                suffix: "g",
                text: $numericText.protein,
                focusedField: focusedField,
                field: .protein
            )
            NutrientInputField(
                title: "Fat",
                suffix: "g",
                text: $numericText.fat,
                focusedField: focusedField,
                field: .fat
            )
            NutrientInputField(
                title: "Carbs",
                suffix: "g",
                text: $numericText.carbs,
                focusedField: focusedField,
                field: .carbs
            )
        }
    }
}

private struct DailyGoalsSaveSection: View {
    let actionTitle: String
    let actionSystemImage: String?
    let actionColor: Color
    let canSave: Bool
    let onSave: () -> Void

    var body: some View {
        Section {
            Button(action: onSave) {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)

                    if let actionSystemImage {
                        Image(systemName: actionSystemImage)
                    }

                    Text(actionTitle)
                        .fontWeight(.semibold)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .foregroundStyle(actionColor)
            }
            .disabled(!canSave)
            .opacity(canSave || actionSystemImage != nil ? 1 : 0.55)
        }
    }
}

struct SettingsGoalsEditorSection: View {
    @Environment(\.modelContext) private var modelContext

    let goals: DailyGoals

    @State private var numericText: DailyGoalsNumericText
    @State private var baselineText: DailyGoalsNumericText
    @State private var didJustSave = false
    @State private var errorMessage: String?
    @State private var saveFeedbackToken = 0
    let focusedField: FocusState<DailyGoalsField?>.Binding

    init(goals: DailyGoals, focusedField: FocusState<DailyGoalsField?>.Binding) {
        self.goals = goals
        let initialText = DailyGoalsNumericText(goals: goals)
        _numericText = State(initialValue: initialText)
        _baselineText = State(initialValue: initialText)
        self.focusedField = focusedField
    }

    private var goalsRepository: DailyGoalsRepository {
        DailyGoalsRepository(modelContext: modelContext)
    }

    private var hasChanges: Bool {
        numericText != baselineText
    }

    private var canSave: Bool {
        hasChanges && numericText.finalizedDraft != nil
    }

    private var actionTitle: String {
        didJustSave && !hasChanges ? "Saved" : "Save Goals"
    }

    private var actionSystemImage: String? {
        didJustSave && !hasChanges ? "checkmark" : nil
    }

    private var actionColor: Color {
        if didJustSave && !hasChanges {
            return .green
        }

        return canSave ? .accentColor : .secondary
    }

    var body: some View {
        Group {
            DailyGoalsSection(
                numericText: $numericText,
                focusedField: focusedField
            )
            DailyGoalsSaveSection(
                actionTitle: actionTitle,
                actionSystemImage: actionSystemImage,
                actionColor: actionColor,
                canSave: canSave,
                onSave: saveGoals
            )
        }
        .errorBanner(message: $errorMessage)
        .sensoryFeedback(.success, trigger: saveFeedbackToken)
        .onChange(of: numericText) { _, newValue in
            if newValue != baselineText {
                didJustSave = false
                errorMessage = nil
            }
        }
        .onDisappear {
            focusedField.wrappedValue = nil
        }
    }

    private func saveGoals() {
        guard canSave, let finalizedDraft = numericText.finalizedDraft else {
            errorMessage = "Please fix invalid numeric values before saving goals."
            return
        }

        dismissKeyboard(focusedField)
        persistGoals(finalizedDraft)
    }

    private func persistGoals(_ finalizedDraft: DailyGoalsDraft) {
        do {
            try goalsRepository.saveGoals(from: finalizedDraft, to: goals, operation: "Save goals")
            baselineText = numericText
            didJustSave = true
            errorMessage = nil
            saveFeedbackToken += 1
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }
}
