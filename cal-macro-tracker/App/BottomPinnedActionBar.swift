import SwiftUI
#if os(iOS)
import UIKit
#endif

enum BottomPinnedActionBarDisplayMode {
    case expanded
    case compactIcon
}

struct BottomPinnedActionBar: View {
    private let compactButtonSize: CGFloat = 60

    let title: String
    let systemImage: String?
    let isDisabled: Bool
    var displayMode: BottomPinnedActionBarDisplayMode = .expanded
    var topPadding: CGFloat = 10
    let action: () -> Void

    @Namespace private var glassNamespace
    @State private var isKeyboardVisible = false

    private var isCompact: Bool {
        displayMode == .compactIcon
    }

    private var bottomPadding: CGFloat {
        isKeyboardVisible ? 72 : 8
    }

    private var buttonBorderShape: ButtonBorderShape {
        isCompact ? .circle : .capsule
    }

    var body: some View {
        buttonContent
            .frame(height: bottomBarHeight, alignment: .bottom)
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
            GlassEffectContainer(spacing: 20) {
                HStack {
                    if isCompact {
                        Spacer(minLength: 0)
                    }

                    glassButton
                        .glassEffectID("add-food-action", in: glassNamespace)
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            fallbackButton
        }
    }

    private var glassButton: some View {
        Button(action: action) {
            labelContent
                .frame(width: labelWidth, height: isCompact ? compactButtonSize : nil)
                .frame(maxWidth: isCompact ? nil : .infinity)
                .padding(.vertical, verticalLabelPadding)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(buttonBorderShape)
        .padding(.horizontal, 20)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: isCompact ? nil : .infinity)
        .disabled(isDisabled)
        .accessibilityLabel(title)
    }

    private var fallbackButton: some View {
        Button(action: action) {
            labelContent
                .foregroundStyle(.white)
                .frame(width: labelWidth, height: isCompact ? compactButtonSize : nil)
                .frame(maxWidth: isCompact ? nil : .infinity)
                .padding(.vertical, verticalLabelPadding)
                .background(isDisabled ? Color.secondary.opacity(0.5) : Color.black)
                .clipShape(isCompact ? AnyShape(Circle()) : AnyShape(Capsule()))
                .padding(.horizontal, 20)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
        }
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .frame(maxWidth: isCompact ? nil : .infinity, alignment: .trailing)
        .background(.ultraThinMaterial)
    }

    private var labelContent: some View {
        HStack(spacing: isCompact ? 0 : 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.headline)
            } else {
                Text(title.prefix(1))
                    .font(.headline.weight(.semibold))
            }

            if !isCompact {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var bottomBarHeight: CGFloat {
        topPadding + bottomPadding + compactButtonSize
    }

    private var labelWidth: CGFloat {
        isCompact ? compactButtonSize : 124
    }

    private var verticalLabelPadding: CGFloat {
        isCompact ? 0 : 18
    }

    private var keyboardWillShowNotification: Notification.Name {
        #if os(iOS)
        UIResponder.keyboardWillShowNotification
        #else
        Notification.Name("BottomPinnedActionBarKeyboardWillShow")
        #endif
    }

    private var keyboardWillHideNotification: Notification.Name {
        #if os(iOS)
        UIResponder.keyboardWillHideNotification
        #else
        Notification.Name("BottomPinnedActionBarKeyboardWillHide")
        #endif
    }
}
