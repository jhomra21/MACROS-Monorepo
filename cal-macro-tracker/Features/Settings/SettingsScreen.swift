import SwiftData
import SwiftUI

struct SettingsScreen: View {
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @Query private var goals: [DailyGoals]

    private var customFoods: [FoodItem] {
        foods.filter { $0.sourceKind == .custom }
    }

    var body: some View {
        List {
            if let goals = goals.first {
                GoalsSection(goals: goals)
            }

            Section("Saved Custom Foods") {
                if customFoods.isEmpty {
                    Text("Custom foods you save while logging will show up here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(customFoods) { food in
                        NavigationLink {
                            CustomFoodEditorScreen(food: food)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(food.name)
                                    .font(.headline)
                                Text("\(food.caloriesPerServing.roundedForDisplay) kcal • \(food.servingDescription)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Section("Coming Next") {
                Label("Barcode scanning", systemImage: "barcode.viewfinder")
                Label("Nutrition label photo scan", systemImage: "camera.viewfinder")
            }
            .foregroundStyle(.secondary)
        }
        .navigationTitle("Settings")
    }
}

@MainActor
private struct GoalsNumericText: Equatable {
    var calories: String
    var protein: String
    var fat: String
    var carbs: String

    init(draft: DailyGoalsDraft) {
        calories = NumericText.editingDisplay(for: draft.calorieGoal)
        protein = NumericText.editingDisplay(for: draft.proteinGoalGrams)
        fat = NumericText.editingDisplay(for: draft.fatGoalGrams)
        carbs = NumericText.editingDisplay(for: draft.carbGoalGrams)
    }

    var hasInvalidValues: Bool {
        [calories, protein, fat, carbs]
            .contains { NumericText.state(for: $0).isInvalid }
    }

    func editingDraft(from draft: DailyGoalsDraft) -> DailyGoalsDraft {
        var editingDraft = draft
        editingDraft.calorieGoal = numericValue(from: calories)
        editingDraft.proteinGoalGrams = numericValue(from: protein)
        editingDraft.fatGoalGrams = numericValue(from: fat)
        editingDraft.carbGoalGrams = numericValue(from: carbs)
        return editingDraft
    }

    func finalizedDraft(from draft: DailyGoalsDraft) -> DailyGoalsDraft? {
        guard !hasInvalidValues else { return nil }
        return editingDraft(from: draft)
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

private struct GoalsSection: View {
    private enum Field: Hashable {
        case calories
        case protein
        case fat
        case carbs
    }

    @Environment(\.modelContext) private var modelContext

    let goals: DailyGoals
    @State private var draft: DailyGoalsDraft
    @State private var numericText: GoalsNumericText
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private var goalsRepository: DailyGoalsRepository {
        DailyGoalsRepository(modelContext: modelContext)
    }

    init(goals: DailyGoals) {
        self.goals = goals
        let initialDraft = DailyGoalsDraft(goals: goals)
        _draft = State(initialValue: initialDraft)
        _numericText = State(initialValue: GoalsNumericText(draft: initialDraft))
    }

    private var finalizedDraft: DailyGoalsDraft? {
        numericText.finalizedDraft(from: draft)
    }

    private var canSave: Bool {
        guard let finalizedDraft else { return false }
        return finalizedDraft.isValid
    }

    var body: some View {
        Section("Daily Goals") {
            NutrientInputField(title: "Calories", suffix: "kcal", text: numericBinding(\.calories), focusedField: $focusedField, field: .calories)
            NutrientInputField(title: "Protein", suffix: "g", text: numericBinding(\.protein), focusedField: $focusedField, field: .protein)
            NutrientInputField(title: "Fat", suffix: "g", text: numericBinding(\.fat), focusedField: $focusedField, field: .fat)
            NutrientInputField(title: "Carbs", suffix: "g", text: numericBinding(\.carbs), focusedField: $focusedField, field: .carbs)

            Button("Save Goals") {
                do {
                    guard let finalizedDraft else {
                        errorMessage = "Please fix invalid numeric values before saving goals."
                        return
                    }

                    try goalsRepository.saveGoals(from: finalizedDraft, to: goals, operation: "Save goals")
                } catch {
                    errorMessage = error.localizedDescription
                    assertionFailure(error.localizedDescription)
                }
            }
            .disabled(!canSave)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap(focusedField: $focusedField)
        .errorBanner(message: $errorMessage)
    }

    private func numericBinding(_ keyPath: WritableKeyPath<GoalsNumericText, String>) -> Binding<String> {
        Binding(
            get: { numericText[keyPath: keyPath] },
            set: { newValue in
                numericText[keyPath: keyPath] = newValue
                draft = numericText.editingDraft(from: draft)
            }
        )
    }
}
