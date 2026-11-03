import SwiftUI

/// Layout-only sources for the two persistent buttons drawn above the card's scroll views.
struct FoodCameraActionSlot: ViewModifier {
    let id: String
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content
                .hidden()
                .matchedGeometryEffect(id: id, in: namespace)
                .accessibilityHidden(true)
        } else {
            content
        }
    }
}
