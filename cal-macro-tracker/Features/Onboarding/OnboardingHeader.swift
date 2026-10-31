import SwiftUI

/// Hero, title and subtitle shared by every onboarding step so they sit in the same place at the same size.
struct OnboardingHeader<Hero: View>: View {
    let title: String
    let subtitle: String?
    var isWelcome = false
    @ViewBuilder let hero: () -> Hero

    var body: some View {
        VStack(spacing: 0) {
            hero().accessibilityHidden(true)
            Text(title)
                .font(isWelcome ? .largeTitle.bold() : .title.bold())
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 16)
            if let subtitle {
                Text(subtitle).font(.body).foregroundStyle(.secondary).padding(.top, 8)
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }
}

struct OnboardingHeaderSymbol: View {
    let symbol: String
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 44

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.tint)
    }
}

extension OnboardingHeader where Hero == OnboardingHeaderSymbol {
    init(symbol: String, title: String, subtitle: String?) {
        self.init(title: title, subtitle: subtitle) { OnboardingHeaderSymbol(symbol: symbol) }
    }
}

/// Spacing shared by every onboarding step.
enum OnboardingLayout {
    static let horizontalInset: CGFloat = 16
    static let verticalPadding: CGFloat = 24
    static let headerSpacing: CGFloat = 28
    static let cardSpacing: CGFloat = 14
}
