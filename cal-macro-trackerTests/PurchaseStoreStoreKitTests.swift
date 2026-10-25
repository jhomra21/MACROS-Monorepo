import Foundation
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
                userInfo: [NSLocalizedDescriptionKey: "StoreKitTest did not expose all three plans. Check local catalog activation and simulator development signing."]
            )
        }
        entitlements = AppEntitlements()
        store = PurchaseStore(entitlements: entitlements)
    }

    override func tearDown() {
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

    func testCancellationDoesNotGrantPro() async throws {
        await store.loadProducts()
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
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
        await store.purchase(.yearly)
        XCTAssertTrue(store.hasPro)
        XCTAssertEqual(entitlements.proSource, .yearly)
        XCTAssertNotNil(entitlements.proExpirationDate)
        let latest = await Transaction.latest(for: ProPlan.yearly.productID)
        guard case let .verified(transaction) = latest else { return XCTFail("Expected verified trial.") }
        XCTAssertEqual(transaction.offer?.type, .introductory)
        try session.expireSubscription(productIdentifier: ProPlan.yearly.productID)
        await store.refreshEntitlements()
        XCTAssertFalse(store.hasPro)
        XCTAssertNil(entitlements.proExpirationDate)
        XCTAssertNil(entitlements.proSource)
    }

    func testMonthlyGrantsPro() async {
        await store.purchase(.monthly)
        XCTAssertTrue(store.hasPro)
        XCTAssertEqual(entitlements.proSource, .monthly)
        XCTAssertNotNil(entitlements.proExpirationDate)
    }

    func testRefundRevokesLifetime() async throws {
        let transaction = try await session.buyProduct(identifier: ProPlan.lifetime.productID)
        await store.refreshEntitlements()
        XCTAssertEqual(entitlements.proSource, .lifetime)
        XCTAssertNil(entitlements.proExpirationDate)
        try session.refundTransaction(identifier: UInt(transaction.id))
        await store.refreshEntitlements()
        XCTAssertFalse(store.hasPro)
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
}
