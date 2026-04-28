import SwiftUI
#if os(iOS)
import UIKit
#endif

struct BottomPinnedActionBar: View {
    let title: String
    let systemImage: String?
    let isDisabled: Bool
    var topPadding: CGFloat = 10
    let action: () -> Void

    @State private var isKeyboardVisible = false

    private var bottomPadding: CGFloat {
        isKeyboardVisible ? 72 : 8
    }

    var body: some View {
        buttonContent
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
            glassButton
        } else {
            fallbackButton
        }
    }

    private var glassButton: some View {
        Button(action: action) {
            labelContent
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        }
        .buttonStyle(.glassProminent)
        .padding(.horizontal, 20)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .disabled(isDisabled)
    }

    private var fallbackButton: some View {
        Button(action: action) {
            labelContent
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(isDisabled ? Color.secondary.opacity(0.5) : Color.black)
                .clipShape(Capsule())
                .padding(.horizontal, 20)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
                .background(.ultraThinMaterial)
        }
        .disabled(isDisabled)
    }

    private var labelContent: some View {
        HStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.headline)
            }

            Text(title)
                .font(.headline.weight(.semibold))
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
