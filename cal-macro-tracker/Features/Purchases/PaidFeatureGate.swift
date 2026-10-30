import SwiftUI

struct PaidFeatureGate<UnlockedContent: View, LockedContent: View>: View {
    @Environment(AppEntitlements.self) private var entitlements

    private let feature: PaidFeature
    private let unlockedContent: UnlockedContent
    private let lockedContent: LockedContent

    init(
        _ feature: PaidFeature,
        @ViewBuilder unlocked: () -> UnlockedContent,
        @ViewBuilder locked: () -> LockedContent
    ) {
        self.feature = feature
        unlockedContent = unlocked()
        lockedContent = locked()
    }

    var body: some View {
        if entitlements.canUse(feature) {
            unlockedContent
        } else {
            lockedContent
        }
    }
}

struct ProLockedRow: View {
    let title: String
    let context: ProPaywallContext
    @State private var isPresentingPaywall = false

    var body: some View {
        Button {
            isPresentingPaywall = true
        } label: {
            HStack {
                Label(title, systemImage: "lock.fill")
                Spacer()
                Text("Pro")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityHint("Opens the Pro paywall")
        .sheet(isPresented: $isPresentingPaywall) {
            ProPaywallSheet(context: context)
        }
    }
}
