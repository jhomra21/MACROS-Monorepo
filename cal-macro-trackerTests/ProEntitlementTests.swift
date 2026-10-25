import Foundation
import StoreKit
import XCTest
@testable import cal_macro_tracker

@MainActor
final class ProEntitlementTests: XCTestCase {
    // Failure inventory: a superseded purchase/restore caller must not return
    // before the dirty reread commits; repeated requests must not overlap scans;
    // events during a reread must drain too; stopped scans must never publish late.
    func testConcurrentRefreshCallersAwaitTheSameCommittedReread() async {
        let firstRead = expectation(description: "First read started")
        let secondRead = expectation(description: "Dirty reread started")
        let nextRead = expectation(description: "Next independent refresh started")
        let source = GatedEntitlementSource(reads: [firstRead, secondRead, nextRead])
        let entitlements = AppEntitlements()
        let store = PurchaseStore(entitlements: entitlements, entitlementSource: source.read)
        let first = Task { await store.refreshEntitlements() }
        await fulfillment(of: [firstRead], timeout: 2)
        let joined = expectation(description: "Two more callers requested refresh")
        joined.expectedFulfillmentCount = 2
        let second = Task {
            joined.fulfill()
            return await store.refreshEntitlements()
        }
        let third = Task {
            joined.fulfill()
            return await store.refreshEntitlements()
        }
        await fulfillment(of: [joined], timeout: 2)
        source.release(1, with: .free)
        await fulfillment(of: [secondRead], timeout: 2)
        XCTAssertFalse(entitlements.hasPro, "An obsolete intermediate snapshot must not publish.")
        XCTAssertEqual(source.maximumConcurrentReads, 1)
        source.release(2, with: .lifetime)
        let results = await [first.value, second.value, third.value]
        XCTAssertTrue(results.allSatisfy(\.hasPro))
        XCTAssertEqual(results, Array(repeating: EntitlementSnapshot.lifetime.resolution, count: 3))
        XCTAssertTrue(entitlements.hasPro, "Publication must precede returning to every caller.")
        XCTAssertEqual(source.readCount, 2)

        let next = Task { await store.refreshEntitlements() }
        await fulfillment(of: [nextRead], timeout: 2)
        source.release(3, with: .free)
        let nextResult = await next.value
        XCTAssertFalse(nextResult.hasPro, "A completed refresh task must not be reused.")
        XCTAssertFalse(entitlements.hasPro)
    }

    func testRequestsDuringDirtyRereadDrainBeforeAnyCallerReturns() async {
        let reads = (1...3).map { expectation(description: "Read \($0) started") }
        let source = GatedEntitlementSource(reads: reads)
        let entitlements = AppEntitlements()
        let store = PurchaseStore(entitlements: entitlements, entitlementSource: source.read)
        let first = Task { await store.refreshEntitlements() }
        await fulfillment(of: [reads[0]], timeout: 2)
        let secondJoined = expectation(description: "Second caller joined")
        let second = Task {
            secondJoined.fulfill()
            return await store.refreshEntitlements()
        }
        await fulfillment(of: [secondJoined], timeout: 2)
        source.release(1, with: .free)
        await fulfillment(of: [reads[1]], timeout: 2)
        let thirdJoined = expectation(description: "Third caller joined during reread")
        let third = Task {
            thirdJoined.fulfill()
            return await store.refreshEntitlements()
        }
        await fulfillment(of: [thirdJoined], timeout: 2)
        source.release(2, with: .lifetime)
        await fulfillment(of: [reads[2]], timeout: 2)
        XCTAssertFalse(entitlements.hasPro, "Dirty lifetime snapshot must not publish before the latest revocation.")
        source.release(3, with: .free)
        let results = await [first.value, second.value, third.value]
        XCTAssertTrue(results.allSatisfy { !$0.hasPro })
        XCTAssertFalse(entitlements.hasPro)
        XCTAssertEqual(source.maximumConcurrentReads, 1)
    }

    func testStoppedRefreshCannotOverwriteNewerCommittedSnapshot() async {
        let reads = (1...2).map { expectation(description: "Read \($0) started") }
        let source = GatedEntitlementSource(reads: reads)
        let entitlements = AppEntitlements()
        let store = PurchaseStore(entitlements: entitlements, entitlementSource: source.read)
        let stopped = Task { await store.refreshEntitlements() }
        await fulfillment(of: [reads[0]], timeout: 2)
        store.stop()
        let latest = Task { await store.refreshEntitlements() }
        await fulfillment(of: [reads[1]], timeout: 2)
        source.release(2, with: .lifetime)
        let latestResult = await latest.value
        XCTAssertTrue(latestResult.hasPro)
        source.release(1, with: .free)
        _ = await stopped.value
        XCTAssertTrue(entitlements.hasPro, "A cancelled scan returning late must not publish or clear a newer task.")
    }

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

@MainActor
private final class GatedEntitlementSource {
    private let reads: [XCTestExpectation]
    private var pending: [Int: CheckedContinuation<EntitlementSnapshot, Never>] = [:]
    private var concurrentReads = 0
    private(set) var readCount = 0
    private(set) var maximumConcurrentReads = 0

    init(reads: [XCTestExpectation]) {
        self.reads = reads
    }

    func read() async -> EntitlementSnapshot {
        readCount += 1
        let index = readCount
        concurrentReads += 1
        maximumConcurrentReads = max(maximumConcurrentReads, concurrentReads)
        defer { concurrentReads -= 1 }
        return await withCheckedContinuation { continuation in
            pending[index] = continuation
            reads[index - 1].fulfill()
        }
    }

    func release(_ index: Int, with snapshot: EntitlementSnapshot) {
        pending.removeValue(forKey: index)?.resume(returning: snapshot)
    }
}

private extension EntitlementSnapshot {
    static var free: Self {
        Self(resolution: AppEntitlements.resolve(from: []))
    }

    static var lifetime: Self {
        Self(
            resolution: AppEntitlements.resolve(from: [
                EntitlementFact(productID: ProPlan.lifetime.productID, productType: .nonConsumable)
            ]))
    }
}
