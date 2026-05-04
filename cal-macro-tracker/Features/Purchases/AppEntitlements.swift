import Observation

@Observable
final class AppEntitlements {
    private(set) var hasFullUnlock = false

    func canUse(_ feature: PaidFeature) -> Bool {
        switch feature.requiredEntitlement {
        case .fullUnlock:
            hasFullUnlock
        }
    }

    func update(fullUnlock: Bool) {
        hasFullUnlock = fullUnlock
    }
}
