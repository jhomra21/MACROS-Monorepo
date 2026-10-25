import StoreKit
import StoreKitTest
import XCTest
import Foundation
@testable import cal_macro_tracker

@MainActor
final class PurchaseStoreStoreKitTests: XCTestCase {
    private var session: SKTestSession!
    private var entitlements: AppEntitlements!
    private var store: PurchaseStore!

    override func setUp() async throws {
        let configurationURL = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "FullUnlock", withExtension: "storekit")
        )
        session = try SKTestSession(contentsOf: configurationURL)
        session.resetToDefaultState()
        session.disableDialogs = true
        let products = try await Product.products(for: [PurchaseStore.fullUnlockProductID])
        guard products.contains(where: { $0.id == PurchaseStore.fullUnlockProductID }) else {
            throw NSError(
                domain: "AppleQA.StoreKitSetup", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "StoreKitTest did not expose the catalog product; no purchase assertion is valid."]
            )
        }
        entitlements = AppEntitlements()
        store = PurchaseStore(entitlements: entitlements)
    }

    override func tearDown() {
        session?.resetToDefaultState()
        session = nil
        store = nil
        entitlements = nil
    }

    func testProductLoadFailureCanRetrySuccessfully() async throws {
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)

        await store.loadProducts()

        XCTAssertNil(store.fullUnlockProduct)
        XCTAssertFalse(store.isLoadingProducts)
        XCTAssertFalse(store.hasFullUnlock)
        XCTAssertNotNil(store.feedback)

        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        await store.loadProducts()

        XCTAssertEqual(store.fullUnlockProduct?.id, PurchaseStore.fullUnlockProductID)
        XCTAssertFalse(store.isLoadingProducts)
        XCTAssertNil(store.feedback)
        XCTAssertFalse(store.hasFullUnlock)
    }

    func testPurchaseFailureDoesNotUnlock() async throws {
        await store.loadProducts()
        _ = try XCTUnwrap(store.fullUnlockProduct)
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase)

        await store.purchaseFullUnlock()

        XCTAssertFalse(store.isPurchasing)
        XCTAssertFalse(store.hasFullUnlock)
        XCTAssertNotNil(store.feedback)
    }

    func testRestoreFailurePreservesLockedState() async throws {
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .appStoreSync)

        await store.restorePurchases()

        XCTAssertFalse(store.isRestoring)
        XCTAssertFalse(store.hasFullUnlock)
        XCTAssertNotNil(store.feedback)
    }

    func testVerifiedTransactionUpdateUnlocksAndRefundRelocks() async throws {
        XCTAssertFalse(store.hasFullUnlock)

        let transaction = try await session.buyProduct(identifier: PurchaseStore.fullUnlockProductID)
        await store.refreshEntitlements()
        XCTAssertTrue(store.hasFullUnlock)

        try session.refundTransaction(identifier: UInt(transaction.id))
        await store.refreshEntitlements()

        XCTAssertFalse(store.hasFullUnlock)
    }
}
