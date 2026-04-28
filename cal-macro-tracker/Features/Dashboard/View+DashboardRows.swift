import SwiftUI

extension View {
    func dashboardDaySwipe<G: Gesture>(_ gesture: G) -> some View {
        contentShape(Rectangle())
            .simultaneousGesture(gesture)
    }

    func dashboardListRow(bottom: CGFloat) -> some View {
        listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: bottom, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
