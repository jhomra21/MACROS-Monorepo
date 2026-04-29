import SwiftUI

enum AddFoodMode: String, CaseIterable, Identifiable {
    case search
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search: "Search"
        case .manual: "Manual"
        }
    }
}

struct ManualFoodEntryScreen: View {
    let loggingDay: CalendarDay?
    let onFoodLogged: () -> Void

    @State private var draft = FoodDraft()
    @State private var numericText = FoodDraftNumericText(draft: FoodDraft())
    @State private var errorMessage: String?
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
                    LogFoodScreen(
                        initialDraft: numericText.finalizedDraft(from: draft) ?? draft,
                        loggingDay: loggingDay,
                        onFoodLogged: onFoodLogged
                    )
                } label: {
                    Text("Continue")
                }
                .disabled(!canContinue)
            }
        }
    }

    private var canContinue: Bool {
        guard let finalizedDraft = numericText.finalizedDraft(from: draft) else { return false }
        return finalizedDraft.canSaveReusableFood
    }
}
