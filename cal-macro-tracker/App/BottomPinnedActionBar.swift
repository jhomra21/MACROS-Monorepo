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
    private let horizontalPadding: CGFloat = 20

    let title: String
    let systemImage: String?
    let isDisabled: Bool
    var displayMode: BottomPinnedActionBarDisplayMode = .expanded
    var topPadding: CGFloat = 10
    var bottomOffset: CGFloat = 0
    let action: () -> Void

    @State private var isKeyboardVisible = false

    private var isCompact: Bool {
        displayMode == .compactIcon
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
            GeometryReader { proxy in
                GlassEffectContainer(spacing: 20) {
                    glassButton(buttonWidth: buttonWidth(for: proxy.size.width))
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .trailing)
            }
        } else {
            fallbackButton
        }
    }

    private func glassButton(buttonWidth: CGFloat) -> some View {
        AppAccentActionButton(
            title: title,
            systemImage: systemImage,
            isCompact: isCompact,
            isDisabled: isDisabled,
            labelWidth: buttonWidth,
            action: action
        )
        .clipped()
        .frame(width: buttonWidth, height: compactButtonSize)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .accessibilityLabel(title)
    }

    private var fallbackButton: some View {
        AppAccentActionButton(
            title: title,
            systemImage: systemImage,
            isCompact: isCompact,
            isDisabled: isDisabled,
            labelWidth: fallbackLabelWidth,
            action: action
        )
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .accessibilityLabel(title)
        .frame(maxWidth: isCompact ? nil : .infinity, alignment: .trailing)
        .background(.ultraThinMaterial)
    }

    private var bottomBarHeight: CGFloat {
        topPadding + bottomPadding + compactButtonSize
    }

    private func buttonWidth(for availableWidth: CGFloat) -> CGFloat {
        isCompact ? compactButtonSize : max(compactButtonSize, availableWidth - horizontalPadding * 2)
    }

    private var fallbackLabelWidth: CGFloat {
        isCompact ? compactButtonSize : 124
    }

}

private struct BottomPinnedKeyboardVisibilityModifier: ViewModifier {
    @Binding var isKeyboardVisible: Bool

    func body(content: Content) -> some View {
        content
            .onAppear {
                isKeyboardVisible = false
            }
            .onDisappear {
                isKeyboardVisible = false
            }
            .onReceive(NotificationCenter.default.publisher(for: keyboardWillShowNotification)) { _ in
                isKeyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: keyboardWillHideNotification)) { _ in
                isKeyboardVisible = false
            }
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

extension View {
    func bottomPinnedKeyboardVisibility(_ isKeyboardVisible: Binding<Bool>) -> some View {
        modifier(BottomPinnedKeyboardVisibilityModifier(isKeyboardVisible: isKeyboardVisible))
    }
}

enum BottomPinnedActionBarMetrics {
    static let bottomPadding: CGFloat = 8
    static let keyboardGap: CGFloat = 20
}

struct AppAccentActionButton: View {
    let title: String
    let systemImage: String?
    let isCompact: Bool
    var isDisabled = false
    var labelWidth: CGFloat?
    let action: () -> Void

    private let buttonHeight: CGFloat = 60

    var body: some View {
        if #available(iOS 26, macOS 26, *) {
            Button(action: action) {
                label
                    .glassEffect(.regular.tint(.accentColor).interactive(), in: .capsule)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.55 : 1)
        } else {
            Button(action: action) {
                label
                    .background(isDisabled ? Color.secondary.opacity(0.5) : Color.black)
                    .clipShape(Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.55 : 1)
        }
    }

    private var label: some View {
        AppAccentActionLabel(title: title, systemImage: systemImage, isCompact: isCompact)
            .foregroundStyle(.white)
            .frame(width: labelWidth, alignment: .trailing)
            .frame(maxWidth: labelWidth == nil ? .infinity : nil)
            .frame(height: buttonHeight)
    }
}

struct AppAccentActionLabel: View {
    let title: String
    let systemImage: String?
    let isCompact: Bool

    var body: some View {
        HStack(spacing: isCompact ? 0 : 8) {
            if let systemImage {
                filledIcon(systemImage)
            } else if isCompact {
                Text(title.prefix(1))
                    .font(.headline.weight(.semibold))
            }

            if !isCompact {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func filledIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 18, height: 18)
            .background(.white, in: Circle())
    }
}

struct BottomPinnedActionContainer<Content: View>: View {
    let height: CGFloat
    let bottomOffset: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .bottom) {
            BottomPinnedEdgeFade()
            content.offset(y: bottomOffset)
        }
        .frame(height: height, alignment: .bottom)
    }
}

private struct BottomPinnedEdgeFade: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: bottomColor.opacity(0), location: 0),
                .init(color: bottomColor.opacity(0.72), location: 0.52),
                .init(color: bottomColor, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea(.container, edges: .bottom)
        .allowsHitTesting(false)
    }

    private var bottomColor: Color {
        PlatformColors.systemBackground
    }
}
