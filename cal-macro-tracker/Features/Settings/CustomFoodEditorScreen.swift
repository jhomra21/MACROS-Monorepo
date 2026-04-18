import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ReusableFoodEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let food: FoodItem
    @State private var draft: FoodDraft
    @State private var numericText: FoodDraftNumericText
    @State private var errorMessage: String?
    @State private var saveFeedbackToken = 0
    @State private var deleteFeedbackToken = 0
    @State private var isRefreshingNutrients = false
    @FocusState private var focusedField: FoodDraftField?

    init(food: FoodItem) {
        self.food = food
        let initialDraft = FoodDraft(foodItem: food, saveAsCustomFood: true)
        _draft = State(initialValue: initialDraft)
        _numericText = State(initialValue: FoodDraftNumericText(draft: initialDraft))
    }

    private var foodRepository: FoodItemRepository {
        FoodItemRepository(modelContext: modelContext)
    }

    private var initialDraft: FoodDraft {
        FoodDraft(foodItem: food, saveAsCustomFood: true)
    }

    private var canSave: Bool {
        guard let finalizedDraft = numericText.finalizedDraft(from: draft) else { return false }
        return finalizedDraft.canSaveReusableFood
    }

    private var sourceURL: URL? {
        guard let sourceURL = draft.sourceURLOrNil else { return nil }
        return URL(string: sourceURL)
    }

    private var navigationTitle: String {
        switch food.sourceKind {
        case .common:
            return "Food"
        case .custom:
            return "Custom Food"
        case .barcodeLookup, .labelScan, .searchLookup:
            return "Saved Food"
        }
    }

    private var saveOperationName: String {
        switch food.sourceKind {
        case .common:
            return "Save food"
        case .custom:
            return "Save custom food"
        case .barcodeLookup:
            return "Save barcode food"
        case .labelScan:
            return "Save label scan food"
        case .searchLookup:
            return "Save searched food"
        }
    }

    private var deleteOperationName: String {
        switch food.sourceKind {
        case .common:
            return "Delete food"
        case .custom:
            return "Delete custom food"
        case .barcodeLookup:
            return "Delete barcode food"
        case .labelScan:
            return "Delete label scan food"
        case .searchLookup:
            return "Delete searched food"
        }
    }

    private var canRefreshNutrients: Bool {
        draft.shouldOfferManualSecondaryNutrientRefresh
            && SecondaryNutrientRepairService.canManuallyRefreshSecondaryNutrients(
                for: draft,
                initialDraft: initialDraft
            )
    }

    private var nutrientRefreshMessage: String {
        return "Extra nutrients are missing for this saved food. Refresh from the source, then save to keep the new values."
    }

    var body: some View {
        FoodDraftEditorForm(
            draft: $draft,
            numericText: $numericText,
            errorMessage: $errorMessage,
            brandPrompt: "Brand (optional)",
            gramsPrompt: "Grams per serving (optional)",
            focusedField: $focusedField,
            trailingKeyboardFields: [],
            previewTotals: nil
        ) {
            if draft.sourceNameOrNil != nil || sourceURL != nil || canRefreshNutrients {
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

                    if canRefreshNutrients {
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
        } footerSections: {
            Section {
                Button("Save") {
                    saveFood()
                }
                .disabled(!canSave || isRefreshingNutrients)
            }

            Section {
                Button("Delete Food", role: .destructive) {
                    deleteFood()
                }
                .disabled(isRefreshingNutrients)
            }
        }
        .navigationTitle(navigationTitle)
        .inlineNavigationTitle()
        .disabled(isRefreshingNutrients)
        .sensoryFeedback(.success, trigger: saveFeedbackToken)
        .sensoryFeedback(.impact(weight: .medium), trigger: deleteFeedbackToken)
    }

    private func saveFood() {
        guard let finalizedDraft = numericText.finalizedDraft(from: draft) else {
            errorMessage = "Please fix invalid numeric values before saving this food."
            return
        }

        dismissEditing()

        DispatchQueue.main.async {
            persistFood(finalizedDraft)
        }
    }

    private func deleteFood() {
        do {
            try foodRepository.deleteReusableFood(food, operation: deleteOperationName)
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

    private func persistFood(_ finalizedDraft: FoodDraft) {
        do {
            let persistedFood = try foodRepository.saveReusableFood(from: finalizedDraft, operation: saveOperationName)
            draft = FoodDraft(foodItem: persistedFood, saveAsCustomFood: true)
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
                        for: draft,
                        initialDraft: initialDraft
                    )
                else {
                    errorMessage = "Unable to refresh nutrients for this saved food."
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

    private func dismissEditing() {
        focusedField = nil
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
