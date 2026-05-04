import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class PurchaseStore {
    static let fullUnlockProductID = "juan-test.cal-macro-tracker.full-unlock"

    private let entitlements: AppEntitlements
    private var transactionUpdatesTask: Task<Void, Never>?

    private(set) var fullUnlockProduct: Product?
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    private(set) var errorMessage: String?

    var hasFullUnlock: Bool {
        entitlements.hasFullUnlock
    }

    init(entitlements: AppEntitlements) {
        self.entitlements = entitlements
    }

    func start() async {
        guard transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }

        await refreshEntitlements()
    }

    func loadProducts() async {
        guard fullUnlockProduct == nil, !isLoadingProducts else { return }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            fullUnlockProduct = try await Product.products(for: [Self.fullUnlockProductID]).first
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load purchase options."
        }
    }

    func purchaseFullUnlock() async {
        if fullUnlockProduct == nil {
            await loadProducts()
        }

        guard let fullUnlockProduct else {
            errorMessage = "Purchase is currently unavailable."
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await fullUnlockProduct.purchase()
            switch result {
            case let .success(verification):
                await applyPurchasedTransaction(from: verification)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase could not be completed."
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            errorMessage = nil
        } catch {
            errorMessage = "Restore could not be completed."
        }
    }

    func refreshEntitlements() async {
        var hasVerifiedFullUnlock = false

        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            guard transaction.productID == Self.fullUnlockProductID else { continue }
            guard transaction.revocationDate == nil else { continue }

            hasVerifiedFullUnlock = true
        }

        entitlements.update(fullUnlock: hasVerifiedFullUnlock)
    }

    private func handle(transactionResult result: VerificationResult<Transaction>) async {
        guard case let .verified(transaction) = result else { return }
        await refreshEntitlements()
        await transaction.finish()
    }

    private func applyPurchasedTransaction(from result: VerificationResult<Transaction>) async {
        guard case let .verified(transaction) = result else {
            errorMessage = "Purchase could not be verified."
            return
        }

        await refreshEntitlements()
        await transaction.finish()
        errorMessage = nil
    }
}
