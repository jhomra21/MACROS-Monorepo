import Foundation
import Observation
import StoreKit
import StoreKitTest
import XCTest
@testable import cal_macro_tracker

@MainActor
final class PurchaseStoreStoreKitTests: XCTestCase {
    private var session: SKTestSession!
    private var entitlements: AppEntitlements!
    private var store: PurchaseStore!

    override func setUp() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "MACROSPro", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        let catalog = try await Product.products(for: ProPlan.allCases.map(\.productID))
        guard catalog.count == ProPlan.allCases.count else {
            throw NSError(
                domain: "WS2.StoreKitSetup", code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "StoreKitTest did not expose all three plans. Check local catalog activation and simulator development signing."
                ]
            )
        }
        entitlements = AppEntitlements()
        store = PurchaseStore(entitlements: entitlements)
    }

    override func tearDown() {
        store?.stop()
        session?.clearTransactions()
        session?.resetToDefaultState()
        store = nil
        entitlements = nil
        session = nil
    }

    func testProductLoadFailureCanRetrySuccessfully() async throws {
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        await store.loadProducts()
        XCTAssertTrue(store.products.isEmpty)
        XCTAssertFalse(store.isLoadingProducts)
        XCTAssertNotNil(store.feedback)
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        await store.loadProducts()
        XCTAssertEqual(Set(store.products.keys), Set(ProPlan.allCases))
        XCTAssertNil(store.feedback)
        XCTAssertTrue(store.isEligibleForIntroOffer)
    }

    func testPurchaseFailureDoesNotGrantPro() async throws {
        await store.loadProducts()
        _ = try XCTUnwrap(store.products[.yearly])
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase)
        await store.purchase(.yearly)
        XCTAssertFalse(store.hasPro)
        XCTAssertFalse(store.isPurchasing)
        XCTAssertNotNil(store.feedback)
    }

    func testCancellationDoesNotGrantPro() async {
        store = PurchaseStore(entitlements: entitlements, purchaseProduct: { _ in .userCancelled })
        await store.purchase(.yearly)
        XCTAssertFalse(store.hasPro)
        XCTAssertFalse(store.isPurchasing)
        XCTAssertNil(store.feedback)

        store = PurchaseStore(entitlements: entitlements, purchaseProduct: { _ in throw StoreKitError.userCancelled })
        await store.purchase(.yearly)
        XCTAssertFalse(store.hasPro)
        XCTAssertFalse(store.isPurchasing)
        XCTAssertNil(store.feedback)
    }

    func testPendingDoesNotGrantPro() async {
        session.askToBuyEnabled = true
        await store.purchase(.yearly)
        XCTAssertFalse(store.hasPro)
        XCTAssertFalse(store.isPurchasing)
        guard case .status = store.feedback else { return XCTFail("Pending purchase must explain approval is needed.") }
    }

    func testTrialGrantsProWithExpirationAndExpiryRemovesIt() async throws {
        await store.start()
        try await expectChange("Trial grants Pro", until: { self.store.hasPro }) {
            await self.store.purchase(.yearly)
        }
        XCTAssertTrue(store.hasPro)
        XCTAssertEqual(entitlements.proSource, .yearly)
        XCTAssertNotNil(entitlements.proExpirationDate)
        let latest = await Transaction.latest(for: ProPlan.yearly.productID)
        guard case let .verified(transaction) = latest else { return XCTFail("Expected verified trial.") }
        XCTAssertEqual(transaction.offer?.type, .introductory)
        try await expectChange("Expiry listener removes Pro", until: { !self.store.hasPro }) {
            try self.session.expireSubscription(productIdentifier: ProPlan.yearly.productID)
            // StoreKit Test needs an explicit sync to publish the simulated expiry to status updates.
            try await AppStore.sync()
        }
        XCTAssertFalse(store.hasPro)
        XCTAssertNil(entitlements.proExpirationDate)
        XCTAssertNil(entitlements.proSource)
    }

    func testMonthlyGrantsPro() async throws {
        await store.start()
        try await expectChange("Monthly purchase grants Pro", until: { self.store.hasPro }) {
            await self.store.purchase(.monthly)
        }
        XCTAssertTrue(store.hasPro)
        XCTAssertEqual(entitlements.proSource, .monthly)
        XCTAssertNotNil(entitlements.proExpirationDate)
    }

    func testRefundRevokesLifetime() async throws {
        await store.start()
        try await expectChange("Transaction listener grants lifetime", until: { self.store.hasPro }) {
            _ = try await self.session.buyProduct(identifier: ProPlan.lifetime.productID)
        }
        XCTAssertEqual(entitlements.proSource, .lifetime)
        XCTAssertNil(entitlements.proExpirationDate)
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == ProPlan.lifetime.productID })
        try await expectChange("Refund listener removes Pro", until: { !self.store.hasPro }) {
            try self.session.refundTransaction(identifier: transaction.identifier)
        }
        XCTAssertFalse(store.hasPro)
    }

    func testAskToBuyApprovalUnlocksThroughListener() async throws {
        await store.start()
        session.askToBuyEnabled = true
        await store.purchase(.monthly)
        XCTAssertFalse(store.hasPro)
        let pending = try XCTUnwrap(session.allTransactions().first(where: \.pendingAskToBuyConfirmation))
        try await expectChange("Approval listener grants Pro", until: { self.store.hasPro }) {
            try self.session.approveAskToBuyTransaction(identifier: pending.identifier)
        }
        XCTAssertEqual(entitlements.proSource, .monthly)
    }

    func testRenewalUpdatesExpirationThroughListener() async throws {
        await store.start()
        try await expectChange("Transaction listener grants monthly Pro", until: { self.store.hasPro }) {
            _ = try await self.session.buyProduct(identifier: ProPlan.monthly.productID)
        }
        let previousExpiration = try XCTUnwrap(entitlements.proExpirationDate)
        try await expectChange(
            "Renewal listener advances expiration",
            until: { self.entitlements.proExpirationDate.map { $0 > previousExpiration } ?? false }
        ) {
            try self.session.forceRenewalOfSubscription(productIdentifier: ProPlan.monthly.productID)
        }
        XCTAssertTrue(store.hasPro)
    }

    func testCancellationUpdatesStatusWithoutRemovingAccess() async throws {
        await store.start()
        try await expectChange("Transaction listener grants monthly Pro", until: { self.store.hasPro }) {
            _ = try await self.session.buyProduct(identifier: ProPlan.monthly.productID)
        }
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == ProPlan.monthly.productID })
        let expiration = try XCTUnwrap(entitlements.proExpirationDate)
        try await expectChange(
            "Status listener reports cancellation",
            until: { self.store.subscriptionStatuses[ProPlan.monthly.productID] == .expires(expiration) }
        ) {
            try self.session.disableAutoRenewForTransaction(identifier: transaction.identifier)
        }
        XCTAssertTrue(store.hasPro)
    }

    func testLegacyGrantsLifetime() async throws {
        _ = try await session.buyProduct(identifier: PurchaseStore.legacyFullUnlockProductID)
        await store.refreshEntitlements()
        XCTAssertTrue(store.hasPro)
        XCTAssertEqual(entitlements.proSource, .legacyFullUnlock)
        XCTAssertNil(entitlements.proExpirationDate)
    }

    func testLifetimeBeatsSubscription() async throws {
        _ = try await session.buyProduct(identifier: ProPlan.yearly.productID)
        _ = try await session.buyProduct(identifier: ProPlan.lifetime.productID)
        await store.refreshEntitlements()
        XCTAssertEqual(entitlements.proSource, .lifetime)
        XCTAssertNil(entitlements.proExpirationDate)
        try session.expireSubscription(productIdentifier: ProPlan.yearly.productID)
        await store.refreshEntitlements()
        XCTAssertTrue(store.hasPro)
        XCTAssertEqual(entitlements.proSource, .lifetime)
    }

    func testRestoreWithNothingReportsStatus() async {
        await store.restorePurchases()
        XCTAssertFalse(store.hasPro)
        XCTAssertFalse(store.isRestoring)
        guard case let .status(message) = store.feedback else { return XCTFail("Expected empty restore status.") }
        XCTAssertTrue(message.contains("No"))
    }

    func testRestoreFailurePreservesEntitlement() async throws {
        _ = try await session.buyProduct(identifier: ProPlan.lifetime.productID)
        await store.refreshEntitlements()
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .appStoreSync)
        await store.restorePurchases()
        XCTAssertTrue(store.hasPro)
        XCTAssertFalse(store.isRestoring)
        guard case .error = store.feedback else { return XCTFail("Expected restore error.") }
    }

    func testIntroEligibilityAfterPriorSubscription() async throws {
        await store.loadProducts()
        XCTAssertTrue(store.isEligibleForIntroOffer)
        _ = try await session.buyProduct(identifier: ProPlan.yearly.productID)
        try session.expireSubscription(productIdentifier: ProPlan.yearly.productID)
        await store.refreshEntitlements()
        XCTAssertFalse(store.isEligibleForIntroOffer)
    }

    private func expectChange(
        _ description: String,
        until predicate: @escaping @MainActor () -> Bool,
        performing action: () async throws -> Void
    ) async throws {
        let changed = expectation(description: description)
        var isObserving = true
        func observe() {
            guard isObserving else { return }
            let satisfied = withObservationTracking {
                predicate()
            } onChange: {
                // Observation fires before mutation; recheck on the next main-actor turn.
                Task { @MainActor in observe() }
            }
            if satisfied {
                isObserving = false
                changed.fulfill()
            }
        }
        observe()
        defer { isObserving = false }
        try await action()
        await fulfillment(of: [changed], timeout: 5)
    }
}
