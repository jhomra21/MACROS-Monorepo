import SwiftData
import SwiftUI

struct CustomFoodEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let food: FoodItem
    @State private var draft: FoodDraft
    @State private var numericText: FoodDraftNumericText
    @State private var errorMessage: String?
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

    private var canSave: Bool {
        guard let finalizedDraft = numericText.finalizedDraft(from: draft) else { return false }
        return finalizedDraft.canSaveReusableFood
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

            Section {
                Button("Save") {
                    saveFood()
                }
                .disabled(!canSave)
            }

            Section {
                Button("Delete Food", role: .destructive) {
                    do {
                        try foodRepository.deleteCustomFood(food, operation: "Delete custom food")
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                        assertionFailure(error.localizedDescription)
                    }
                }
            }
        }
        .navigationTitle("Custom Food")
        .inlineNavigationTitle()
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap(focusedField: $focusedField)
        .errorBanner(message: $errorMessage)
    }

    private func saveFood() {
        do {
            guard let finalizedDraft = numericText.finalizedDraft(from: draft) else {
                errorMessage = "Please fix invalid numeric values before saving this food."
                return
            }

            let persistedFood = try foodRepository.saveReusableCustomFood(from: finalizedDraft, operation: "Save custom food")
            draft = FoodDraft(foodItem: persistedFood, saveAsCustomFood: true)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }
}
