import SwiftUI

private struct KeyboardNavigationToolbar<Field: Hashable>: ToolbarContent {
    let focusedField: FocusState<Field?>.Binding
    let fields: [Field]

    private var currentIndex: Int? {
        guard let focusedField = focusedField.wrappedValue else { return nil }
        return fields.firstIndex(of: focusedField)
    }

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Button {
                moveFocus(offset: -1)
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(!canMove(offset: -1))

            Button {
                moveFocus(offset: 1)
            } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(!canMove(offset: 1))

            Spacer()

            Button("Done") {
                dismissKeyboard(focusedField)
            }
        }
    }

    private func canMove(offset: Int) -> Bool {
        guard let currentIndex else { return false }
        let nextIndex = currentIndex + offset
        return fields.indices.contains(nextIndex)
    }

    private func moveFocus(offset: Int) {
        guard let currentIndex else { return }
        let nextIndex = currentIndex + offset
        guard fields.indices.contains(nextIndex) else { return }
        focusedField.wrappedValue = fields[nextIndex]
    }
}

extension View {
    func keyboardNavigationToolbar<Field: Hashable>(
        focusedField: FocusState<Field?>.Binding,
        fields: [Field]
    ) -> some View {
        toolbar {
            KeyboardNavigationToolbar(focusedField: focusedField, fields: fields)
        }
    }
}
