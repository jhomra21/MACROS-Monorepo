import SwiftUI

struct ErrorBanner: ViewModifier {
    @Binding var message: String?

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
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
    }
}

extension View {
    func errorBanner(message: Binding<String?>) -> some View {
        modifier(ErrorBanner(message: message))
    }
}
