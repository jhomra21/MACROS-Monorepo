#if os(iOS)
import SwiftUI

struct FoodCameraDetailsEditor: View {
    @Binding var editor: FoodLogEditorState
    let onQuantityChange: (Double) -> Void
    let isExpanded: Bool
    @FocusState private var focusedField: FoodDraftField?

    var body: some View {
        FoodLogEditorSections(
            editor: $editor,
            focusedField: $focusedField,
            rowBackground: .clear,
            leadingSections: AnyView(Section { quantity }),
            showsQuantity: false,
            scrollsToFocusedField: true
        )
        .scrollContentBackground(.hidden)
        .onChange(of: editor.servingsAmount) { _, amount in onQuantityChange(amount) }
        .onChange(of: isExpanded, initial: true) { _, expanded in
            guard expanded else {
                dismissKeyboard($focusedField)
                return
            }
            AccessibilityNotification.LayoutChanged().post()
        }
    }

    private var quantity: some View {
        FoodQuantitySection(
            quantityMode: $editor.quantityMode,
            servingsAmount: $editor.servingsAmount,
            gramsAmount: $editor.gramsAmount,
            canLogByGrams: editor.previewDraft.canLogByGrams,
            gramsPerServing: editor.previewDraft.gramsPerServing,
            gramLoggingMessage: "Add grams per serving to enable gram-based logging.",
            isInline: true
        )
    }

}

struct CameraDirtyDismissal: ViewModifier {
    let isDirty: Bool
    let onDiscard: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            content.dismissalConfirmationDialog("Discard changes?", shouldPresent: isDirty) {
                Button("Discard Changes", role: .destructive, action: onDiscard)
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Your food edits haven’t been logged.")
            }
            // iOS 27's zoom cover bypasses the native dismissal dialog (see E2E evidence).
            // Block its dirty gesture; Close still presents the explicit discard dialog.
            .interactiveDismissDisabled(isDirty)
        } else {
            content.interactiveDismissDisabled(isDirty)
        }
    }
}
#endif
