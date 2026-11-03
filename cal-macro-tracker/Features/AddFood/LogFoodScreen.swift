import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct LogFoodScreen: View {
    @Environment(SharingSyncService.self) private var sharingSyncService
    @Environment(\.modelContext) private var modelContext

    let initialDraft: FoodDraft
    let loggingDay: CalendarDay?
    let reviewNotes: [String]
    let requiredReviewNutrients: [RequiredNutritionReviewNutrient]
    let previewImageData: Data?
    let onFoodLogged: () -> Void

    @State private var editor: FoodLogEditorState
    @State private var logFeedbackToken = 0
    @FocusState private var focusedField: FoodDraftField?

    init(
        initialDraft: FoodDraft,
        loggingDay: CalendarDay? = nil,
        initialQuantityMode: QuantityMode = .servings,
        initialQuantityAmount: Double? = nil,
        reviewNotes: [String] = [],
        requiredReviewNutrients: [RequiredNutritionReviewNutrient] = [],
        previewImageData: Data? = nil,
        onFoodLogged: @escaping () -> Void = {}
    ) {
        self.initialDraft = initialDraft
        self.loggingDay = loggingDay
        self.reviewNotes = reviewNotes
        self.requiredReviewNutrients = requiredReviewNutrients
        self.previewImageData = previewImageData
        self.onFoodLogged = onFoodLogged
        _editor = State(
            initialValue: FoodLogEditorState(
                initialDraft: initialDraft,
                initialQuantityMode: initialQuantityMode,
                initialQuantityAmount: initialQuantityAmount,
                reviewNotes: reviewNotes,
                requiredReviewNutrients: requiredReviewNutrients,
                previewImageData: previewImageData
            ))
    }

    var body: some View {
        FoodLogEditorSections(editor: $editor, focusedField: $focusedField)
            .safeAreaInset(edge: .bottom) {
                BottomPinnedActionBar(
                    title: "Log Food",
                    systemImage: nil,
                    isDisabled: !editor.canSave
                ) {
                    saveEntry()
                }
            }
            .sensoryFeedback(.success, trigger: logFeedbackToken)
            .navigationTitle("Log Food")
            .inlineNavigationTitle()
    }

    private var logEntryRepository: LogEntryRepository {
        LogEntryRepository(modelContext: modelContext, onDailyTotalsChanged: sharingSyncService.syncAfterDailyTotalsChange)
    }

    private func saveEntry() {
        guard let loggingAction = editor.loggingAction else {
            editor.errorMessage = "Please fix invalid numeric values before logging food."
            return
        }

        dismissKeyboard($focusedField)
        persistEntry(loggingAction)
    }

    private func persistEntry(_ loggingAction: FoodDraftLoggingAction) {
        do {
            try logEntryRepository.logFood(
                action: loggingAction,
                loggedAt: loggingDay?.date(matchingTimeOf: .now) ?? .now,
                operation: "Log food"
            )
            editor.errorMessage = nil
            logFeedbackToken += 1
            onFoodLogged()
        } catch {
            editor.errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }

}
