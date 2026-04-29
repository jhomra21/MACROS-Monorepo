import SwiftUI
#if os(iOS)
import UIKit
#endif

struct BottomPinnedDualAction {
    let title: String
    let systemImage: String
    let action: () -> Void
}

struct BottomPinnedDualActionBar: View {
    private let compactButtonSize: CGFloat = 60
    private let horizontalPadding: CGFloat = 20
    private let buttonSpacing: CGFloat = 10

    let leadingAction: BottomPinnedDualAction
    let trailingAction: BottomPinnedDualAction
    var displayMode: BottomPinnedActionBarDisplayMode = .expanded
    var topPadding: CGFloat = 10
    var bottomOffset: CGFloat = 0

    @State private var isKeyboardVisible = false

    private var isCompact: Bool {
        displayMode == .compactIcon
    }

    private var bottomPadding: CGFloat {
        isKeyboardVisible ? 72 : 8
    }

    var body: some View {
        buttonContent
            .frame(height: bottomBarHeight, alignment: .bottom)
            .offset(y: bottomOffset)
            .onReceive(NotificationCenter.default.publisher(for: keyboardWillShowNotification)) { _ in
                isKeyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: keyboardWillHideNotification)) { _ in
                isKeyboardVisible = false
            }
    }

    @ViewBuilder
    private var buttonContent: some View {
        if #available(iOS 26, macOS 26, *) {
            GlassEffectContainer(spacing: buttonSpacing) {
                buttons
            }
        } else {
            buttons
                .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var buttons: some View {
        if isCompact {
            VStack(spacing: buttonSpacing) {
                actionButton(leadingAction)
                actionButton(trailingAction)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        } else {
            HStack(spacing: buttonSpacing) {
                actionButton(leadingAction)
                actionButton(trailingAction)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        }
    }

    private func actionButton(_ action: BottomPinnedDualAction) -> some View {
        Button(action: action.action) {
            labelContent(for: action)
                .foregroundStyle(.white)
                .frame(maxWidth: isCompact ? compactButtonSize : .infinity)
                .frame(height: compactButtonSize)
                .background(fallbackBackground)
                .clipShape(Capsule())
                .contentShape(Capsule())
                .ifAvailableGlassTintedCapsule()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.title)
    }

    private func labelContent(for action: BottomPinnedDualAction) -> some View {
        AppAccentActionLabel(title: action.title, systemImage: action.systemImage, isCompact: isCompact)
    }

    @ViewBuilder
    private var fallbackBackground: some View {
        if #unavailable(iOS 26, macOS 26) {
            Color.black
        }
    }

    private var bottomBarHeight: CGFloat {
        topPadding + bottomPadding + (isCompact ? compactStackHeight : compactButtonSize)
    }

    private var compactStackHeight: CGFloat {
        compactButtonSize * 2 + buttonSpacing
    }

    private var keyboardWillShowNotification: Notification.Name {
        #if os(iOS)
        UIResponder.keyboardWillShowNotification
        #else
        Notification.Name("BottomPinnedDualActionBarKeyboardWillShow")
        #endif
    }

    private var keyboardWillHideNotification: Notification.Name {
        #if os(iOS)
        UIResponder.keyboardWillHideNotification
        #else
        Notification.Name("BottomPinnedDualActionBarKeyboardWillHide")
        #endif
    }
}

private extension View {
    @ViewBuilder
    func ifAvailableGlassTintedCapsule() -> some View {
        if #available(iOS 26, macOS 26, *) {
            self.glassEffect(.regular.tint(.accentColor).interactive(), in: .capsule)
        } else {
            self
        }
    }
}
