import SwiftUI

struct ErrorBanner: ViewModifier {
    @Binding var message: String?
    var title: String
    var retryTitle: String?
    var onRetry: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .alert(
                title,
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
        title: String = "Something Went Wrong",
        retryTitle: String? = nil,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorBanner(message: message, title: title, retryTitle: retryTitle, onRetry: onRetry))
    }
}
