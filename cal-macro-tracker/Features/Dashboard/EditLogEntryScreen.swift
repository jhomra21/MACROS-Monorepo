import SwiftData
import SwiftUI

struct EditLogEntryScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entry: LogEntry

    @State private var draft: FoodDraft
    @State private var numericText: FoodDraftNumericText
    @State private var quantityMode: QuantityMode
    @State private var quantityAmountText: String
    @State private var errorMessage: String?
    @FocusState private var focusedField: FoodDraftField?

    init(entry: LogEntry) {
        self.entry = entry

        var initialDraft = FoodDraft()
        initialDraft.name = entry.foodName
        initialDraft.brand = entry.brand ?? ""
        initialDraft.source = entry.sourceKind
        initialDraft.servingDescription = entry.servingDescription
        initialDraft.gramsPerServing = entry.gramsPerServing
        initialDraft.caloriesPerServing = entry.caloriesPerServing
        initialDraft.proteinPerServing = entry.proteinPerServing
        initialDraft.fatPerServing = entry.fatPerServing
        initialDraft.carbsPerServing = entry.carbsPerServing
        initialDraft.saveAsCustomFood = false

        let initialQuantityAmountText = NumericText.editingDisplay(for: entry.quantityModeKind == .servings ? entry.servingsConsumed : entry.gramsConsumed)
        _draft = State(initialValue: initialDraft)
        _numericText = State(initialValue: FoodDraftNumericText(draft: initialDraft))
        _quantityMode = State(initialValue: entry.quantityModeKind)
        _quantityAmountText = State(initialValue: initialQuantityAmountText.isEmpty ? "1" : initialQuantityAmountText)
    }

    private var finalizedDraft: FoodDraft? {
        numericText.finalizedDraft(from: draft)
    }

    private var quantityAmountValue: Double {
        NumericText.parse(quantityAmountText) ?? 0
    }

    private var previewDraft: FoodDraft {
        finalizedDraft ?? draft
    }

    private var previewTotals: NutritionSnapshot {
        NutritionMath.consumedNutrition(for: previewDraft, mode: quantityMode, amount: quantityAmountValue)
    }

    private var canSave: Bool {
        guard let finalizedDraft else { return false }
        return finalizedDraft.canLog(quantityMode: quantityMode, quantityAmount: quantityAmountValue)
    }

    var body: some View {
        FoodDraftEditorForm(
            draft: $draft,
            numericText: $numericText,
            errorMessage: $errorMessage,
            brandPrompt: "Brand",
            gramsPrompt: "Grams per serving",
            focusedField: $focusedField,
            keyboardFields: FoodDraftField.formOrder + [.quantityAmount],
            previewTotals: previewTotals
        ) {
            Section("Quantity") {
                Picker("Mode", selection: $quantityMode) {
                    Text("Servings").tag(QuantityMode.servings)
                    Text("Grams").tag(QuantityMode.grams)
                }
                .pickerStyle(.segmented)

                if quantityMode == .grams && previewDraft.canLogByGrams == false {
                    Text("Add grams per serving to log by grams.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                TextField(quantityMode == .servings ? "Servings eaten" : "Grams eaten", text: $quantityAmountText)
                    .focused($focusedField, equals: .quantityAmount)
                    .numericKeyboard()
            }
        } footerSections: {
            Section {
                Button("Save Changes") {
                    saveChanges()
                }
                .disabled(!canSave)
            }

            Section {
                Button("Delete Entry", role: .destructive) {
                    deleteEntry()
                }
            }
        }
        .navigationTitle("Edit Entry")
        .inlineNavigationTitle()
        .onAppear {
            if !previewDraft.canLogByGrams {
                quantityMode = .servings
            }
        }
        .onChange(of: previewDraft.canLogByGrams) { _, canLogByGrams in
            if !canLogByGrams && quantityMode == .grams {
                quantityMode = .servings
            }
        }
    }

    private var logEntryRepository: LogEntryRepository {
        LogEntryRepository(modelContext: modelContext)
    }

    private func saveChanges() {
        do {
            guard let finalizedDraft else {
                errorMessage = "Please fix invalid numeric values before saving changes."
                return
            }

            try logEntryRepository.saveEdits(
                entry: entry,
                draft: finalizedDraft,
                quantityMode: quantityMode,
                quantityAmount: quantityAmountValue,
                operation: "Save entry changes"
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }

    private func deleteEntry() {
        do {
            try logEntryRepository.delete(entry: entry, operation: "Delete entry")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }
}
