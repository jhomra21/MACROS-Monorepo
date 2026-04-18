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
    @State private var isRefreshingNutrients = false
    @State private var canRefreshNutrients = false
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

    private var sourceURL: URL? {
        guard let sourceURL = draft.sourceURLOrNil else { return nil }
        return URL(string: sourceURL)
    }

    private var shouldShowSourceSection: Bool {
        draft.sourceNameOrNil != nil || sourceURL != nil || shouldShowNutrientRefreshButton
    }

    private var shouldShowNutrientRefreshButton: Bool {
        draft.shouldOfferManualSecondaryNutrientRefresh && canRefreshNutrients
    }

    private var nutrientRefreshMessage: String {
        return "Extra nutrients are missing for this entry. Refresh from the source, then save to keep the new values."
    }

    private var nutrientRefreshAvailabilityID: Int {
        var hasher = Hasher()
        hasher.combine(draft.secondaryNutrientRepairKey)
        hasher.combine(draft.secondaryNutrientRepairTarget)
        hasher.combine(draft.shouldOfferManualSecondaryNutrientRefresh)
        hasher.combine(entry.foodItemID)
        return hasher.finalize()
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
            if shouldShowSourceSection {
                Section("Source") {
                    if let sourceName = draft.sourceNameOrNil {
                        LabeledContent("Provider") {
                            Text(sourceName)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let sourceURL {
                        Link(destination: sourceURL) {
                            Label("View Source", systemImage: "link")
                        }
                    }

                    if shouldShowNutrientRefreshButton {
                        Text(nutrientRefreshMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button(isRefreshingNutrients ? "Refreshing Nutrients…" : "Refresh Nutrients") {
                            refreshNutrients()
                        }
                        .disabled(isRefreshingNutrients)
                    }
                }
            }

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
                .disabled(!canSave || isRefreshingNutrients)
            }

            Section {
                Button("Delete Entry", role: .destructive) {
                    deleteEntry()
                }
                .disabled(isRefreshingNutrients)
            }
        }
        .navigationTitle("Edit Entry")
        .inlineNavigationTitle()
        .disabled(isRefreshingNutrients)
        .sensoryFeedback(.success, trigger: saveFeedbackToken)
        .sensoryFeedback(.impact(weight: .medium), trigger: deleteFeedbackToken)
        .task(id: nutrientRefreshAvailabilityID) {
            updateNutrientRefreshAvailability()
        }
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

    private func refreshNutrients() {
        dismissEditing()
        isRefreshingNutrients = true

        Task { @MainActor in
            do {
                guard
                    let refreshedDraft = try await SecondaryNutrientRepairService.manuallyRefreshedDraft(
                        for: entry,
                        currentDraft: draft,
                        modelContext: modelContext
                    )
                else {
                    errorMessage = "Unable to refresh nutrients for this entry."
                    isRefreshingNutrients = false
                    return
                }

                draft = refreshedDraft
                numericText = FoodDraftNumericText(draft: refreshedDraft)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }

            isRefreshingNutrients = false
        }
    }

    private func updateNutrientRefreshAvailability() {
        guard draft.shouldOfferManualSecondaryNutrientRefresh else {
            canRefreshNutrients = false
            return
        }

        do {
            canRefreshNutrients = try SecondaryNutrientRepairService.canManuallyRefreshSecondaryNutrients(
                for: entry,
                currentDraft: draft,
                modelContext: modelContext
            )
        } catch {
            canRefreshNutrients = false
        }
    }

    private func dismissEditing() {
        focusedField = nil
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
