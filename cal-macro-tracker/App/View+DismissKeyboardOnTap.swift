import SwiftUI

struct DismissKeyboardOnTapModifier<Field: Hashable>: ViewModifier {
    let focusedField: FocusState<Field?>.Binding

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            TapGesture().onEnded {
                focusedField.wrappedValue = nil
            }
        )
    }
}

extension View {
    func dismissKeyboardOnTap<Field: Hashable>(focusedField: FocusState<Field?>.Binding) -> some View {
        modifier(DismissKeyboardOnTapModifier(focusedField: focusedField))
    }
}
