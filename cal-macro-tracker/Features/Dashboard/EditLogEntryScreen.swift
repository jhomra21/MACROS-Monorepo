import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct EditLogEntryScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entry: LogEntry

    @State private var draft: FoodDraft
    @State private var numericText: FoodDraftNumericText
    @State private var quantityMode: QuantityMode
    @State private var quantityAmountText: String
    @State private var errorMessage: String?
    @State private var saveFeedbackToken = 0
    @State private var deleteFeedbackToken = 0
    @FocusState private var focusedField: FoodDraftField?

    init(entry: LogEntry) {
        self.entry = entry
        let initialDraft = FoodDraft(logEntry: entry, saveAsCustomFood: false)

        let initialQuantityAmountText = NumericText.editingDisplay(
            for: entry.quantityModeKind == .servings ? entry.servingsConsumed : entry.gramsConsumed)
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
            trailingKeyboardFields: [.quantityAmount],
            previewTotals: previewTotals
        ) {
            FoodQuantitySection(
                quantityMode: $quantityMode,
                canLogByGrams: previewDraft.canLogByGrams,
                showsGramLoggingMessageOnlyInGramsMode: true
            ) { quantityMode in
                AppNumericTextField(
                    quantityMode == .servings ? "Servings eaten" : "Grams eaten",
                    text: $quantityAmountText,
                    focusedField: $focusedField,
                    field: .quantityAmount
                )
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
        .sensoryFeedback(.success, trigger: saveFeedbackToken)
        .sensoryFeedback(.impact(weight: .medium), trigger: deleteFeedbackToken)
    }

    private var logEntryRepository: LogEntryRepository {
        LogEntryRepository(modelContext: modelContext)
    }

    private func saveChanges() {
        guard let finalizedDraft else {
            errorMessage = "Please fix invalid numeric values before saving changes."
            return
        }

        dismissEditing()

        DispatchQueue.main.async {
            persistChanges(finalizedDraft)
        }
    }

    private func deleteEntry() {
        do {
            try logEntryRepository.delete(entry: entry, operation: "Delete entry")
            errorMessage = nil
            deleteFeedbackToken += 1

            DispatchQueue.main.async {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }

    private func persistChanges(_ finalizedDraft: FoodDraft) {
        do {
            try logEntryRepository.saveEdits(
                entry: entry,
                draft: finalizedDraft,
                quantityMode: quantityMode,
                quantityAmount: quantityAmountValue,
                operation: "Save entry changes"
            )
            errorMessage = nil
            saveFeedbackToken += 1

            DispatchQueue.main.async {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }

    private func dismissEditing() {
        focusedField = nil
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
