#if os(iOS)
import SwiftUI

struct FoodCameraDetailsEditor: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Binding var editor: FoodLogEditorState
    let goals: MacroGoalsSnapshot
    let onQuantityChange: (Double) -> Void
    let onLog: () -> Void
    @FocusState private var focusedField: FoodDraftField?
    @AccessibilityFocusState private var headerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if !scrollsSummary {
                summary
                quantity
                    .padding(.horizontal, 16)
            }
            FoodLogEditorSections(
                editor: $editor,
                focusedField: $focusedField,
                rowBackground: .clear,
                leadingSections: scrollsSummary
                    ? AnyView(
                        Section {
                            summary
                            quantity
                        }) : nil,
                showsQuantity: false,
                scrollsToFocusedField: true
            )
            .scrollContentBackground(.hidden)
            Button {
                dismissKeyboard($focusedField)
                onLog()
            } label: {
                Text("Log").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(!editor.canSave)
            .padding(16)
        }
        .onChange(of: editor.servingsAmount) { _, amount in onQuantityChange(amount) }
        .onAppear {
            headerFocused = true
            AccessibilityNotification.LayoutChanged().post()
        }
    }

    private var summary: some View {
        FoodCameraResultPanel(
            content: .barcode(
                editor.previewDraft,
                servings: editor.previewLoggingAction.quantityMultiplier ?? editor.servingsAmount,
                logged: false
            ),
            goals: goals,
            onChangeServings: { editor.servingsAmount = $0 },
            onChangeName: { _ in },
            onLog: onLog,
            onDetails: {},
            onManual: {},
            onSearch: {},
            showsActions: false,
            showsServings: editor.quantityMode == .servings
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Food details")
        .accessibilityAddTraits(.isHeader)
        .accessibilityFocused($headerFocused)
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

    private var scrollsSummary: Bool {
        dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact
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
