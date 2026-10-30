import SwiftUI

enum AddFoodMode: String, CaseIterable, Identifiable {
    case search
    case manual

    var id: String { rawValue }
}

struct ManualFoodEntryScreen: View {
    let loggingDay: CalendarDay?
    let onFoodLogged: () -> Void

    @State private var draft = FoodDraft()
    @State private var numericText = FoodDraftNumericText(draft: FoodDraft())
    @State private var errorMessage: String?
    @State private var isPresentingLogFood = false
    @FocusState private var focusedField: FoodDraftField?

    var body: some View {
        FoodDraftEditorForm(
            draft: $draft,
            numericText: $numericText,
            errorMessage: $errorMessage,
            configuration: FoodDraftEditorConfiguration(
                brandPrompt: "Brand (optional)",
                gramsPrompt: "Grams per serving (optional)"
            ),
            focusedField: $focusedField
        ) {
            EmptyView()
        } footerSections: {
            Section {
                NavigationLink {
                    MealEditorScreen(loggingDay: loggingDay, onMealLogged: onFoodLogged)
                } label: {
                    Label("Create Meal", systemImage: "fork.knife")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomPinnedActionBar(
                title: "Continue",
                systemImage: nil,
                isDisabled: !canContinue
            ) {
                isPresentingLogFood = true
            }
        }
        .navigationDestination(isPresented: $isPresentingLogFood) {
            LogFoodScreen(
                initialDraft: numericText.finalizedDraft(from: draft) ?? draft,
                loggingDay: loggingDay,
                onFoodLogged: onFoodLogged
            )
        }
    }

    private var canContinue: Bool {
        guard let finalizedDraft = numericText.finalizedDraft(from: draft) else { return false }
        return finalizedDraft.canSaveReusableFood
    }
}
