import SwiftUI

enum AppTopBarStyle {
    static let titleFont: Font = .system(size: 20, weight: .semibold)
    static let iconFont: Font = .system(size: 18.75, weight: .medium)
}

extension View {
    func appTopBarTitleStyle() -> some View {
        font(AppTopBarStyle.titleFont)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .transaction { $0.animation = nil }
            .accessibilityAddTraits(.isHeader)
    }

    func appTopBarIconStyle() -> some View {
        font(AppTopBarStyle.iconFont)
    }
}
