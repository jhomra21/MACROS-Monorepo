import Foundation
import StoreKit
import XCTest
@testable import cal_macro_tracker

@MainActor
final class ProEntitlementTests: XCTestCase {
    func testSubscriptionStatusDistinguishesRenewalAndCancellation() {
        let expiration = Date(timeIntervalSince1970: 2_000_000_000)
        XCTAssertEqual(
            ProSubscriptionStatus.resolve(state: .subscribed, willAutoRenew: true, expiration: expiration, graceExpiration: nil),
            .renews(expiration))
        XCTAssertEqual(
            ProSubscriptionStatus.resolve(state: .subscribed, willAutoRenew: false, expiration: expiration, graceExpiration: nil),
            .expires(expiration))
        XCTAssertEqual(
            ProSubscriptionStatus.resolve(state: .subscribed, willAutoRenew: true, expiration: nil, graceExpiration: nil),
            .active)
    }

    func testGraceUsesGraceDeadlineAndRetryDoesNotPromiseAccess() {
        let expiration = Date(timeIntervalSince1970: 1_000)
        let grace = Date(timeIntervalSince1970: 2_000)
        XCTAssertEqual(
            ProSubscriptionStatus.resolve(state: .inGracePeriod, willAutoRenew: true, expiration: expiration, graceExpiration: grace),
            .paymentIssue(accessUntil: grace))
        XCTAssertEqual(
            ProSubscriptionStatus.resolve(state: .inBillingRetryPeriod, willAutoRenew: true, expiration: expiration, graceExpiration: nil),
            .paymentIssue(accessUntil: nil))
        XCTAssertEqual(
            ProSubscriptionStatus.resolve(state: .expired, willAutoRenew: false, expiration: expiration, graceExpiration: nil),
            .expired)
        XCTAssertEqual(
            ProSubscriptionStatus.resolve(state: .revoked, willAutoRenew: true, expiration: expiration, graceExpiration: nil),
            .revoked)
    }

    func testAllFeaturesRequirePro() {
        let entitlements = AppEntitlements()
        for feature in PaidFeature.allCases {
            XCTAssertFalse(entitlements.canUse(feature))
        }
        entitlements.update(AppEntitlements.resolve(from: [fact(.lifetime)]))
        for feature in PaidFeature.allCases {
            XCTAssertTrue(entitlements.canUse(feature))
        }
    }

    func testRevocationClearsSourceAndExpiration() {
        let entitlements = AppEntitlements()
        entitlements.update(AppEntitlements.resolve(from: [fact(.yearly)]))
        entitlements.update(AppEntitlements.resolve(from: []))
        XCTAssertFalse(entitlements.hasPro)
        XCTAssertNil(entitlements.proSource)
        XCTAssertNil(entitlements.proExpirationDate)
        XCTAssertFalse(entitlements.hasActiveSubscription)
    }

    func testLifetimeDoesNotHideActiveSubscription() {
        let entitlements = AppEntitlements()
        entitlements.update(AppEntitlements.resolve(from: [fact(.lifetime), fact(.monthly)]))
        XCTAssertEqual(entitlements.proSource, .lifetime)
        XCTAssertTrue(entitlements.hasActiveSubscription)
        entitlements.update(AppEntitlements.resolve(from: [fact(.lifetime)]))
        XCTAssertTrue(entitlements.hasPro)
        XCTAssertFalse(entitlements.hasActiveSubscription)
    }

    func testProductMappingExcludesUnknownProducts() {
        XCTAssertNil(ProSource(productID: "unrelated"))
        XCTAssertEqual(ProSource(productID: "fullunlock001"), .legacyFullUnlock)
        for plan in ProPlan.allCases {
            XCTAssertNotNil(ProSource(productID: plan.productID))
        }
    }

    func testLifetimeBeatsEitherSubscriptionInBothOrders() {
        for subscription in [ProPlan.monthly, .yearly] {
            let inputs = [fact(subscription), fact(.lifetime)]
            let resolution = AppEntitlements.resolve(from: inputs)
            XCTAssertEqual(resolution, AppEntitlements.resolve(from: inputs.reversed()))
            XCTAssertEqual(resolution.source, .lifetime)
            XCTAssertNil(resolution.expiration)
            XCTAssertTrue(resolution.hasActiveSubscription)
        }
    }

    func testLegacyProvidesLifetimeAccessInBothOrders() {
        let legacy = EntitlementFact(productID: "fullunlock001", productType: .nonConsumable)
        let resolution = AppEntitlements.resolve(from: [legacy, fact(.yearly)])
        XCTAssertEqual(resolution, AppEntitlements.resolve(from: [fact(.yearly), legacy]))
        XCTAssertTrue(resolution.hasPro)
        XCTAssertEqual(resolution.source, .legacyFullUnlock)
        XCTAssertNil(resolution.expiration)
        XCTAssertTrue(AppEntitlements.resolve(from: [legacy]).hasPro)
        XCTAssertFalse(AppEntitlements.resolve(from: [legacy]).hasActiveSubscription)
    }

    func testSubscriptionSelectionPreservesExpirationInBothOrders() {
        let inputs = [fact(.monthly), fact(.yearly)]
        let resolution = AppEntitlements.resolve(from: inputs)
        XCTAssertEqual(resolution, AppEntitlements.resolve(from: inputs.reversed()))
        XCTAssertEqual(resolution.source, .yearly)
        XCTAssertEqual(resolution.expiration, expiration)
        XCTAssertTrue(resolution.hasActiveSubscription)
    }

    func testReducerRejectsUnverifiedRevokedUpgradedAndUnrelatedFacts() {
        let invalid = [
            EntitlementFact(productID: ProPlan.yearly.productID, productType: .autoRenewable, isVerified: false),
            EntitlementFact(productID: ProPlan.lifetime.productID, productType: .nonConsumable, revocationDate: expiration),
            EntitlementFact(productID: ProPlan.monthly.productID, productType: .autoRenewable, isUpgraded: true),
            EntitlementFact(productID: "unrelated", productType: .nonConsumable),
            EntitlementFact(productID: ProPlan.yearly.productID, productType: .nonConsumable),
            EntitlementFact(productID: ProPlan.lifetime.productID, productType: .autoRenewable),
            EntitlementFact(productID: "fullunlock001", productType: .consumable)
        ]
        for fact in invalid {
            XCTAssertEqual(AppEntitlements.resolve(from: [fact]), AppEntitlements.resolve(from: []))
        }
        XCTAssertEqual(AppEntitlements.resolve(from: invalid + [fact(.monthly)]).source, .monthly)
    }

    func testReducerPreservesGraceEvenAfterBillingExpiration() {
        let past = Date(timeIntervalSince1970: 1_000)
        let grace = EntitlementFact(
            productID: ProPlan.yearly.productID, productType: .autoRenewable,
            expirationDate: past, renewalState: .inGracePeriod)
        let resolution = AppEntitlements.resolve(from: [grace])
        XCTAssertTrue(resolution.hasPro)
        XCTAssertTrue(resolution.hasActiveSubscription)
        XCTAssertEqual(resolution.expiration, past)
    }

    func testReducerDoesNotGuessExpiryWhenRenewalStatusIsUnavailable() {
        let transaction = EntitlementFact(
            productID: ProPlan.monthly.productID, productType: .autoRenewable,
            expirationDate: Date(timeIntervalSince1970: 1_000))
        XCTAssertTrue(AppEntitlements.resolve(from: [transaction]).hasPro)
    }

    func testReducerRejectsExpiredRevokedAndBillingRetrySubscriptions() {
        for state in [Product.SubscriptionInfo.RenewalState.expired, .revoked, .inBillingRetryPeriod] {
            let subscription = EntitlementFact(
                productID: ProPlan.monthly.productID, productType: .autoRenewable,
                expirationDate: expiration, renewalState: state)
            XCTAssertFalse(AppEntitlements.resolve(from: [subscription]).hasPro)
            let withLifetime = AppEntitlements.resolve(from: [subscription, fact(.lifetime)])
            XCTAssertEqual(withLifetime.source, .lifetime)
            XCTAssertFalse(withLifetime.hasActiveSubscription)
        }
    }

    func testDuplicateSubscriptionFactsChooseLatestExpirationInBothOrders() {
        let earlier = EntitlementFact(
            productID: ProPlan.yearly.productID, productType: .autoRenewable,
            expirationDate: expiration.addingTimeInterval(-100))
        let inputs = [fact(.yearly), earlier]
        XCTAssertEqual(AppEntitlements.resolve(from: inputs), AppEntitlements.resolve(from: inputs.reversed()))
        XCTAssertEqual(AppEntitlements.resolve(from: inputs).expiration, expiration)
    }

    func testEmptyInputResolvesToFree() {
        let resolution = AppEntitlements.resolve(from: [])
        XCTAssertFalse(resolution.hasPro)
        XCTAssertNil(resolution.source)
        XCTAssertNil(resolution.expiration)
        XCTAssertFalse(resolution.hasActiveSubscription)
    }

    private let expiration = Date(timeIntervalSince1970: 2_000_000_000)

    private func fact(_ plan: ProPlan) -> EntitlementFact {
        EntitlementFact(
            productID: plan.productID, productType: plan == .lifetime ? .nonConsumable : .autoRenewable,
            expirationDate: plan == .lifetime ? nil : expiration)
    }
}
