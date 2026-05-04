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
