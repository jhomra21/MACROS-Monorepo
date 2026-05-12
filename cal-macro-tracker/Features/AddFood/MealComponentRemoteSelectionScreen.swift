import SwiftData
import SwiftUI

struct MealComponentRemoteSelectionScreen: View {
    @Environment(\.modelContext) private var modelContext

    let result: RemoteSearchResult
    let onSelect: (MealComponentDraft) -> Void

    @State private var draft: FoodDraft?
    @State private var numericText: FoodDraftNumericText?
    @State private var quantityMode: QuantityMode = .servings
    @State private var servingsAmount: Double = 1
    @State private var gramsAmount: Double = 100
    @State private var errorMessage: String?
    @FocusState private var focusedField: FoodDraftField?

    private var reviewDraft: FoodDraft? {
        guard let draft, let numericText else { return nil }
        return numericText.editingDraft(from: draft)
    }

    private var finalizedDraft: FoodDraft? {
        guard let draft, let numericText else { return nil }
        return numericText.finalizedDraft(from: draft)
    }

    private var canSave: Bool {
        guard let finalizedDraft else { return false }
        return finalizedDraft.canLog(quantityMode: quantityMode, quantityAmount: activeQuantityAmount)
            && unresolvedRequiredReviewNutrients.isEmpty
    }

    private var activeQuantityAmount: Double {
        quantityMode == .servings ? servingsAmount : gramsAmount
    }

    private var unresolvedRequiredReviewNutrients: [RequiredNutritionReviewNutrient] {
        guard let reviewDraft else { return result.requiredReviewNutrients }
        return result.requiredReviewNutrients.filter { reviewDraft.isRequiredNutrientPositive($0) == false }
    }

    var body: some View {
        Group {
            if let draft, let numericText {
                reviewForm(
                    draft: draft,
                    draftBinding: Binding(
                        get: { self.draft ?? draft },
                        set: { self.draft = $0 }
                    ),
                    numericTextBinding: Binding(
                        get: { self.numericText ?? numericText },
                        set: { self.numericText = $0 }
                    )
                )
            } else if let errorMessage {
                ContentUnavailableView(
                    "Unable to load food",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
                .padding()
            } else {
                ProgressView("Preparing food…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Review Food")
        .inlineNavigationTitle()
        .task {
            await loadDraftIfNeeded()
        }
    }

    private var foodRepository: FoodItemRepository {
        FoodItemRepository(modelContext: modelContext)
    }

    private var sourceURL: URL? {
        guard let sourceURL = draft?.sourceURLOrNil else { return nil }
        return URL(string: sourceURL)
    }

    private var combinedReviewNotes: [String] {
        guard result.requiredReviewNutrients.isEmpty == false else {
            return result.reviewNotes
        }

        return [
            NutritionLabelParser.reviewRequiredNutrientsMessage(result.requiredReviewNutrients)
        ] + result.reviewNotes
    }

    private func reviewForm(
        draft: FoodDraft,
        draftBinding: Binding<FoodDraft>,
        numericTextBinding: Binding<FoodDraftNumericText>
    ) -> some View {
        FoodDraftEditorForm(
            draft: draftBinding,
            numericText: numericTextBinding,
            errorMessage: $errorMessage,
            configuration: FoodDraftEditorConfiguration(
                brandPrompt: "Brand (optional)",
                gramsPrompt: "Grams per serving (optional)"
            ),
            focusedField: $focusedField
        ) {
            FoodDraftSourceSection(
                title: "Online Packaged Food",
                notes: combinedReviewNotes,
                sourceName: draft.sourceNameOrNil,
                sourceURL: sourceURL
            )

            if result.requiredReviewNutrients.isEmpty == false {
                Section("Required Review") {
                    ForEach(result.requiredReviewNutrients, id: \.self) { nutrient in
                        let isResolved = reviewDraft?.isRequiredNutrientPositive(nutrient) == true
                        Label(
                            isResolved ? "\(nutrient.displayName) reviewed" : "\(nutrient.displayName) is required",
                            systemImage: isResolved ? "checkmark.circle.fill" : "exclamationmark.triangle"
                        )
                        .foregroundStyle(isResolved ? .green : .orange)
                    }
                }
            }

            FoodQuantitySection(
                quantityMode: $quantityMode,
                servingsAmount: $servingsAmount,
                gramsAmount: $gramsAmount,
                canLogByGrams: draft.canLogByGrams,
                gramsPerServing: draft.gramsPerServing,
                gramLoggingMessage: "Add grams per serving to enable gram-based meal components."
            )
        } footerSections: {
            Section {
                Button("Add to Meal") {
                    saveFood()
                }
                .disabled(!canSave)
            }
        }
    }

    @MainActor
    private func loadDraftIfNeeded() async {
        guard draft == nil, errorMessage == nil else { return }

        do {
            var loadedDraft: FoodDraft
            if let cachedFood = try result.cachedFood(using: foodRepository) {
                loadedDraft = FoodDraft(foodItem: cachedFood, saveAsCustomFood: true)
            } else {
                loadedDraft = try result.makeDraft()
                loadedDraft.saveAsCustomFood = true
            }

            draft = loadedDraft
            numericText = FoodDraftNumericText(draft: loadedDraft)
            gramsAmount = loadedDraft.gramsPerServing ?? 100
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveFood() {
        guard let finalizedDraft else {
            errorMessage = "Please fix invalid numeric values before adding this food."
            return
        }

        do {
            let savedFood = try foodRepository.saveReusableFood(
                from: finalizedDraft,
                operation: "Save meal component food"
            )
            onSelect(
                MealComponentDraft(
                    food: savedFood,
                    quantityMode: quantityMode,
                    quantityAmount: activeQuantityAmount
                )
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
