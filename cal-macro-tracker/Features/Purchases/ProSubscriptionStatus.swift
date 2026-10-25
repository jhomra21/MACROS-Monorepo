import Foundation
import StoreKit

enum ProSubscriptionStatus: Equatable {
    case active
    case renews(Date)
    case expires(Date)
    case paymentIssue(accessUntil: Date?)
    case expired
    case revoked

    static func resolve(
        state: Product.SubscriptionInfo.RenewalState, willAutoRenew: Bool,
        expiration: Date?, graceExpiration: Date?
    ) -> Self {
        switch state {
        case .subscribed:
            guard let expiration else { return .active }
            return willAutoRenew ? .renews(expiration) : .expires(expiration)
        case .inGracePeriod:
            return .paymentIssue(accessUntil: graceExpiration)
        case .inBillingRetryPeriod:
            // Billing retry without grace does not entitle the subscriber to service.
            return .paymentIssue(accessUntil: nil)
        case .expired: return .expired
        case .revoked: return .revoked
        default: return .active
        }
    }

    var text: String {
        switch self {
        case .active: "Active"
        case let .renews(date): "Renews \(date.formatted(date: .abbreviated, time: .omitted))"
        case let .expires(date): "Expires \(date.formatted(date: .abbreviated, time: .omitted))"
        case let .paymentIssue(date):
            if let date {
                "Payment issue, access until \(date.formatted(date: .abbreviated, time: .omitted))"
            } else {
                "Payment issue"
            }
        case .expired: "Expired"
        case .revoked: "Revoked"
        }
    }
}
