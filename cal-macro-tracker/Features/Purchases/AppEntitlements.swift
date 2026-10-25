import Foundation
import Observation
import StoreKit

struct EntitlementFact {
    let productID: String
    let productType: Product.ProductType
    let isVerified: Bool
    let revocationDate: Date?
    let expirationDate: Date?
    let isUpgraded: Bool
    let renewalState: Product.SubscriptionInfo.RenewalState?

    init(
        productID: String, productType: Product.ProductType, isVerified: Bool = true,
        revocationDate: Date? = nil, expirationDate: Date? = nil, isUpgraded: Bool = false,
        renewalState: Product.SubscriptionInfo.RenewalState? = nil
    ) {
        self.productID = productID
        self.productType = productType
        self.isVerified = isVerified
        self.revocationDate = revocationDate
        self.expirationDate = expirationDate
        self.isUpgraded = isUpgraded
        self.renewalState = renewalState
    }
}

struct EntitlementResolution: Equatable {
    let source: ProSource?
    let expiration: Date?
    let hasActiveSubscription: Bool

    var hasPro: Bool { source != nil }
}

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
    private(set) var hasActiveSubscription = false

    // Facts come only from currentEntitlements. Its subscriptions include grace;
    // a past billing expiration is not enough to deny access.
    static func resolve(from facts: [EntitlementFact]) -> EntitlementResolution {
        var source: ProSource?
        var expiration: Date?
        var hasActiveSubscription = false
        for fact in facts {
            guard fact.isVerified, fact.revocationDate == nil, !fact.isUpgraded,
                let candidate = ProSource(productID: fact.productID),
                fact.productType == (candidate.isSubscription ? .autoRenewable : .nonConsumable)
            else { continue }
            if candidate.isSubscription, let state = fact.renewalState,
                state != .subscribed && state != .inGracePeriod
            {
                continue
            }
            hasActiveSubscription = hasActiveSubscription || candidate.isSubscription
            if candidate.priority > (source?.priority ?? -1)
                || (candidate == source && (fact.expirationDate ?? .distantPast) > (expiration ?? .distantPast))
            {
                source = candidate
                expiration = candidate.isSubscription ? fact.expirationDate : nil
            }
        }
        return EntitlementResolution(source: source, expiration: expiration, hasActiveSubscription: hasActiveSubscription)
    }

    func update(_ resolution: EntitlementResolution) {
        hasPro = resolution.hasPro
        proSource = resolution.source
        proExpirationDate = resolution.expiration
        hasActiveSubscription = resolution.hasActiveSubscription
    }

    func canUse(_ feature: PaidFeature) -> Bool {
        switch feature.requiredEntitlement {
        case .pro:
            hasPro
        }
    }

}
