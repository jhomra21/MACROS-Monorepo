#if os(iOS)
import SwiftUI

struct FoodCameraDetailsEditor: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Binding var editor: FoodLogEditorState
    let goals: MacroGoalsSnapshot
    let onQuantityChange: (Double) -> Void
    let isExpanded: Bool
    let isKeyboardVisible: Bool
    let actionNamespace: Namespace.ID?
    @FocusState private var focusedField: FoodDraftField?
    @AccessibilityFocusState private var headerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Less") {}
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .modifier(FoodCameraActionSlot(id: "details", namespace: actionNamespace))
                    .hidden()
                Spacer()
            }
            .padding([.horizontal, .top], 16)
            if !scrollsSummary {
                VStack(spacing: 0) {
                    summary
                    quantity
                        .padding(.horizontal, 16)
                }
                .frame(height: isKeyboardVisible ? 0 : nil)
                .clipped()
                .accessibilityHidden(isKeyboardVisible)
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
            } label: {
                Text("Log").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(!editor.canSave)
            .modifier(FoodCameraActionSlot(id: "log", namespace: actionNamespace))
            .hidden()
            .padding(16)
        }
        .onChange(of: editor.servingsAmount) { _, amount in onQuantityChange(amount) }
        .onChange(of: isExpanded, initial: true) { _, expanded in
            guard expanded else {
                dismissKeyboard($focusedField)
                return
            }
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
            onLog: {},
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
