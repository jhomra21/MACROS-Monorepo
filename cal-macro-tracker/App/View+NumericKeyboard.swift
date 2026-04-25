import SwiftUI
#if os(iOS)
import UIKit
#endif

@MainActor
enum KeyboardSupport {
    static func dismissFirstResponder() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

@MainActor
func dismissKeyboard<Field: Hashable>(_ focusedField: FocusState<Field?>.Binding) {
    focusedField.wrappedValue = nil
    KeyboardSupport.dismissFirstResponder()
}

extension View {
    @ViewBuilder
    func numericKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}
