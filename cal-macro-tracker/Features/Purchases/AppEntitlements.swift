import Foundation
import Observation

enum ProSource: Equatable {
    case monthly, yearly, lifetime, legacyFullUnlock

    init?(productID: String) {
        switch productID {
        case ProPlan.monthly.productID: self = .monthly
        case ProPlan.yearly.productID: self = .yearly
        case ProPlan.lifetime.productID: self = .lifetime
        case PurchaseStore.legacyFullUnlockProductID: self = .legacyFullUnlock
        default: return nil
        }
    }

    var priority: Int {
        switch self {
        case .monthly: 0
        case .yearly: 1
        case .legacyFullUnlock: 2
        case .lifetime: 3
        }
    }

    var isSubscription: Bool {
        self == .monthly || self == .yearly
    }
}

@Observable
final class AppEntitlements {
    private(set) var hasPro = false
    private(set) var proSource: ProSource?
    private(set) var proExpirationDate: Date?

    func canUse(_ feature: PaidFeature) -> Bool {
        switch feature.requiredEntitlement {
        case .pro:
            hasPro
        }
    }

    func update(pro: Bool, source: ProSource?, expiration: Date?) {
        hasPro = pro
        proSource = pro ? source : nil
        proExpirationDate = pro ? expiration : nil
    }
}
