import SwiftUI

enum AppTopBarStyle {
    static let titleFont: Font = .system(size: 20, weight: .semibold)
    static let iconFont: Font = .system(size: 18.75, weight: .medium)
}

struct AppTopBarLeadingTitle: ToolbarContent {
    let title: String
    let compactTitle: String?

    init(_ title: String, compactTitle: String? = nil) {
        self.title = title
        self.compactTitle = compactTitle
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .appTopBarLeading) {
            if let compactTitle {
                ViewThatFits(in: .horizontal) {
                    Text(title)
                        .appTopBarTitleStyle()
                        .fixedSize(horizontal: true, vertical: false)

                    Text(compactTitle)
                        .appTopBarTitleStyle()
                        .fixedSize(horizontal: true, vertical: false)
                }
            } else {
                Text(title)
                    .appTopBarTitleStyle()
            }
        }
        .sharedBackgroundVisibility(.hidden)
    }
}

extension View {
    func appTopBarTitleStyle() -> some View {
        font(AppTopBarStyle.titleFont)
            .lineLimit(1)
            .transaction { $0.animation = nil }
            .accessibilityAddTraits(.isHeader)
    }

    func appTopBarIconStyle() -> some View {
        font(AppTopBarStyle.iconFont)
    }
}
