import SwiftData
import SwiftUI

struct LogFoodScreen: View {
    @Environment(\.modelContext) private var modelContext

    let logDate: Date
    let initialDraft: FoodDraft
    let onFoodLogged: () -> Void

    @State private var draft: FoodDraft
    @State private var quantityMode: QuantityMode
    @State private var servingsAmount: Double
    @State private var gramsAmount: Double
    @State private var numericText: FoodDraftNumericText
    @State private var errorMessage: String?
    @FocusState private var focusedField: FoodDraftField?

    init(logDate: Date, initialDraft: FoodDraft, onFoodLogged: @escaping () -> Void = {}) {
        self.logDate = logDate
        self.initialDraft = initialDraft
        self.onFoodLogged = onFoodLogged
        _draft = State(initialValue: initialDraft)
        _quantityMode = State(initialValue: .servings)
        _servingsAmount = State(initialValue: 1)
        _gramsAmount = State(initialValue: initialDraft.gramsPerServing ?? 100)
        _numericText = State(initialValue: FoodDraftNumericText(draft: initialDraft))
    }

    private var activeAmount: Double {
        quantityMode == .servings ? servingsAmount : gramsAmount
    }

    private var previewDraft: FoodDraft {
        numericText.finalizedDraft(from: draft) ?? draft
    }

    private var previewTotals: NutritionSnapshot {
        NutritionMath.consumedNutrition(for: previewDraft, mode: quantityMode, amount: activeAmount)
    }

    private var shouldSaveCustomFood: Bool {
        draft.saveAsCustomFood || (initialDraft.source == .common && hasMeaningfulChangesFromInitial)
    }

    private var hasMeaningfulChangesFromInitial: Bool {
        draft.name != initialDraft.name ||
        draft.brand != initialDraft.brand ||
        draft.servingDescription != initialDraft.servingDescription ||
        draft.gramsPerServing != initialDraft.gramsPerServing ||
        draft.caloriesPerServing != initialDraft.caloriesPerServing ||
        draft.proteinPerServing != initialDraft.proteinPerServing ||
        draft.fatPerServing != initialDraft.fatPerServing ||
        draft.carbsPerServing != initialDraft.carbsPerServing
    }

    private var canSave: Bool {
        guard let finalizedDraft = numericText.finalizedDraft(from: draft) else { return false }
        return finalizedDraft.canLog(quantityMode: quantityMode, quantityAmount: activeAmount)
    }

    var body: some View {
        Form {
            FoodDraftFormSections(
                draft: $draft,
                numericText: $numericText,
                brandPrompt: "Brand (optional)",
                gramsPrompt: "Grams per serving (optional)",
                focusedField: $focusedField
            )

            Section("Quantity") {
                Picker("Mode", selection: $quantityMode) {
                    Text("Servings").tag(QuantityMode.servings)
                    Text("Grams").tag(QuantityMode.grams)
                }
                .pickerStyle(.segmented)

                if quantityMode == .servings {
                    Stepper(value: $servingsAmount, in: 0.25...20, step: 0.25) {
                        LabeledContent("Servings") {
                            Text(servingsAmount.roundedForDisplay)
                                .monospacedDigit()
                        }
                    }
                } else {
                    Stepper(value: $gramsAmount, in: 1...2000, step: 5) {
                        LabeledContent("Grams") {
                            Text("\(gramsAmount.roundedForDisplay) g")
                                .monospacedDigit()
                        }
                    }
                }

                if !draft.canLogByGrams {
                    Text("Add grams per serving to enable gram-based logging.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Preview") {
                previewRow(label: "Calories", value: previewTotals.calories, suffix: "kcal")
                previewRow(label: "Protein", value: previewTotals.protein, suffix: "g")
                previewRow(label: "Fat", value: previewTotals.fat, suffix: "g")
                previewRow(label: "Carbs", value: previewTotals.carbs, suffix: "g")
            }

            Section {
                Toggle("Save as reusable custom food", isOn: $draft.saveAsCustomFood)
                if hasMeaningfulChangesFromInitial && initialDraft.source == .common {
                    Text("Because you changed a common food, a custom copy will be saved automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Log Food") {
                    saveEntry()
                }
                .disabled(!canSave)
            }
        }
        .navigationTitle("Log Food")
        .inlineNavigationTitle()
        .onAppear {
            if !draft.canLogByGrams {
                quantityMode = .servings
            }
        }
        .onChange(of: draft.canLogByGrams) { _, canLogByGrams in
            if !canLogByGrams && quantityMode == .grams {
                quantityMode = .servings
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap(focusedField: $focusedField)
        .errorBanner(message: $errorMessage)
    }

    private func previewRow(label: String, value: Double, suffix: String) -> some View {
        LabeledContent(label) {
            Text("\(value.roundedForDisplay) \(suffix)")
                .monospacedDigit()
        }
    }

    private var logEntryRepository: LogEntryRepository {
        LogEntryRepository(modelContext: modelContext)
    }

    private func saveEntry() {
        do {
            guard let finalizedDraft = numericText.finalizedDraft(from: draft) else {
                errorMessage = "Please fix invalid numeric values before logging food."
                return
            }

            try logEntryRepository.logFood(
                draft: finalizedDraft,
                shouldSaveCustomFood: shouldSaveCustomFood,
                logDate: logDate,
                quantityMode: quantityMode,
                quantityAmount: activeAmount,
                operation: "Log food"
            )
            onFoodLogged()
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }
}
