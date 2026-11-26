import SwiftUI

/// Explains streaks, badges, the weekly flex day and comparing weeks, before the optional Pro step.
struct OnboardingStreaksScreen: View {
    let onContinue: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: OnboardingLayout.headerSpacing) {
                    OnboardingHeader(
                        title: "Build a streak",
                        subtitle: "Log once a day and watch it grow. No pressure, and nothing leaves your phone."
                    ) {
                        StreakPaletteReader { palette in
                            HStack(spacing: -8) {
                                ForEach([StreakBadge.oneWeek, .oneMonth, .threeMonths]) { badge in
                                    StreakMedallionView(badge: badge, palette: palette, diameter: 64)
                                }
                            }
                        }
                    }
                    VStack(spacing: OnboardingLayout.cardSpacing) {
                        row(
                            "calendar", "Log to keep it going",
                            "A day counts when you log at least one food by the end of the next day.")
                        row(
                            "rosette", "Earn badges",
                            "At 7, 30, 90, 180 and 365 days. Once you earn one, it is yours to keep.")
                        row(
                            "leaf", "One flex day a week",
                            "Plan a day off ahead of time, or your first missed day each week is covered for you.")
                        row(
                            "person.2", "Compare weeks",
                            "If you use live sharing, you can compare your week with the people you share with.")
                    }
                }
                .padding(.horizontal, OnboardingLayout.horizontalInset)
                .padding(.vertical, OnboardingLayout.verticalPadding)
            }
            .scrollBounceBehavior(.basedOnSize)

            BottomPinnedActionBar(
                title: "Continue", systemImage: nil, isDisabled: false,
                edgeFadeColor: PlatformColors.groupedBackground, action: onContinue)
        }
        .background(PlatformColors.groupedBackground)
        .navigationTitle("")
        .inlineNavigationTitle()
    }

    private func row(_ symbol: String, _ title: String, _ detail: String) -> some View {
        let icon = Image(systemName: symbol)
            .font(.title2)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.tint)
            .frame(width: 30)
            .accessibilityHidden(true)
        let texts = VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))

        return layout {
            icon
            texts
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardBackground(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }
}
