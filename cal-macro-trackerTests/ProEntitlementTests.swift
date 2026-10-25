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
        entitlements.update(pro: true, source: .lifetime, expiration: nil)
        for feature in PaidFeature.allCases {
            XCTAssertTrue(entitlements.canUse(feature))
        }
    }

    func testRevocationClearsSourceAndExpiration() {
        let entitlements = AppEntitlements()
        entitlements.update(pro: true, source: .yearly, expiration: Date().addingTimeInterval(600))
        entitlements.update(pro: false, source: nil, expiration: nil)
        XCTAssertFalse(entitlements.hasPro)
        XCTAssertNil(entitlements.proSource)
        XCTAssertNil(entitlements.proExpirationDate)
        XCTAssertFalse(entitlements.hasActiveSubscription)
    }

    func testLifetimeDoesNotHideActiveSubscription() {
        let entitlements = AppEntitlements()
        entitlements.update(pro: true, source: .lifetime, expiration: nil, hasActiveSubscription: true)
        XCTAssertEqual(entitlements.proSource, .lifetime)
        XCTAssertTrue(entitlements.hasActiveSubscription)
        entitlements.update(pro: true, source: .lifetime, expiration: nil, hasActiveSubscription: false)
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

    func testLifetimePriorityIsHigherThanEitherSubscription() {
        XCTAssertGreaterThan(ProSource.lifetime.priority, ProSource.yearly.priority)
        XCTAssertGreaterThan(ProSource.legacyFullUnlock.priority, ProSource.monthly.priority)
    }
}
