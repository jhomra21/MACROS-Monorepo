import SwiftUI

struct ErrorBanner: ViewModifier {
    @Binding var message: String?
    var retryTitle: String?
    var onRetry: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .alert(
                "Action Failed",
                isPresented: Binding(
                    get: { message != nil },
                    set: { isPresented in
                        if !isPresented {
                            message = nil
                        }
                    }
                )
            ) {
                if let retryTitle, let onRetry {
                    Button(retryTitle) {
                        message = nil
                        onRetry()
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
    }
}

extension View {
    func errorBanner(
        message: Binding<String?>,
        retryTitle: String? = nil,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorBanner(message: message, retryTitle: retryTitle, onRetry: onRetry))
    }
}
