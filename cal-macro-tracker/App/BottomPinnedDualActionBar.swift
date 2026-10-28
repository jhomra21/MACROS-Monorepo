import SwiftUI
#if os(iOS)
import UIKit
#endif

struct BottomPinnedDualAction {
    let title: String
    let systemImage: String
    let action: () -> Void
    var role: ButtonRole? = nil
    var transitionSourceID: String? = nil
}

struct BottomPinnedDualActionBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let compactButtonSize: CGFloat = 60
    private let horizontalPadding: CGFloat = 20
    private let buttonSpacing: CGFloat = 10

    let leadingAction: BottomPinnedDualAction
    let trailingAction: BottomPinnedDualAction
    var transitionNamespace: Namespace.ID? = nil
    var displayMode: BottomPinnedActionBarDisplayMode = .expanded
    var compactActionsAreHorizontal = false
    var topPadding: CGFloat = 10
    var bottomOffset: CGFloat = 0

    @State private var isKeyboardVisible = false

    private var isCompact: Bool {
        displayMode == .compactIcon || dynamicTypeSize.isAccessibilitySize
    }

    private var bottomPadding: CGFloat {
        isKeyboardVisible ? BottomPinnedActionBarMetrics.keyboardGap + bottomOffset : BottomPinnedActionBarMetrics.bottomPadding
    }

    var body: some View {
        BottomPinnedActionContainer(height: bottomBarHeight, bottomOffset: bottomOffset) {
            buttonContent
        }
        .bottomPinnedKeyboardVisibility($isKeyboardVisible)
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
            Group {
                if compactActionsAreHorizontal {
                    HStack(spacing: buttonSpacing) {
                        actionButton(leadingAction)
                        actionButton(trailingAction)
                    }
                } else {
                    VStack(spacing: buttonSpacing) {
                        actionButton(leadingAction)
                        actionButton(trailingAction)
                    }
                }
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

    @ViewBuilder
    private func actionButton(_ action: BottomPinnedDualAction) -> some View {
        let button = AppAccentActionButton(
            title: action.title,
            systemImage: action.systemImage,
            isCompact: isCompact,
            labelWidth: isCompact ? compactButtonSize : nil,
            action: action.action,
            role: action.role
        )
        .accessibilityLabel(action.title)

        if let sourceID = action.transitionSourceID, let namespace = transitionNamespace {
            GlassEffectContainer(spacing: 0) {
                button
            }
            .matchedTransitionSource(id: sourceID, in: namespace) {
                $0.clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            }
        } else {
            button
        }
    }

    private var bottomBarHeight: CGFloat {
        topPadding + bottomPadding + (isCompact && !compactActionsAreHorizontal ? compactStackHeight : compactButtonSize)
    }

    private var compactStackHeight: CGFloat {
        compactButtonSize * 2 + buttonSpacing
    }

}
