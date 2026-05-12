import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class PurchaseStore {
    static let fullUnlockProductID = "fullunlock001"

    enum Feedback {
        case error(String)
        case status(String)
    }

    private let entitlements: AppEntitlements
    private var transactionUpdatesTask: Task<Void, Never>?

    private(set) var fullUnlockProduct: Product?
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    private(set) var feedback: Feedback?

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
            if case .error = feedback {
                feedback = nil
            }
        } catch {
            feedback = .error("Unable to load purchase options.")
        }
    }

    func purchaseFullUnlock() async {
        guard !isPurchasing, !isRestoring else { return }

        isPurchasing = true
        defer { isPurchasing = false }

        if fullUnlockProduct == nil {
            await loadProducts()
        }

        guard let fullUnlockProduct else {
            feedback = .error("Purchase is currently unavailable.")
            return
        }

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
            feedback = .error("Purchase could not be completed.")
        }
    }

    func restorePurchases() async {
        guard !isPurchasing, !isRestoring else { return }

        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if hasFullUnlock {
                feedback = .status("Purchases restored.")
            } else {
                feedback = .status("No full app unlock purchase was found for this Apple Account.")
            }
        } catch {
            feedback = .error("Restore could not be completed.")
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

    #if DEBUG
    func setDebugFullUnlock(_ isUnlocked: Bool) {
        entitlements.update(fullUnlock: isUnlocked)
        feedback = nil
    }
    #endif

    private func handle(transactionResult result: VerificationResult<Transaction>) async {
        guard case let .verified(transaction) = result else { return }
        await refreshEntitlements()
        await transaction.finish()
    }

    private func applyPurchasedTransaction(from result: VerificationResult<Transaction>) async {
        guard case let .verified(transaction) = result else {
            feedback = .error("Purchase could not be verified.")
            return
        }

        applyFullUnlock(from: transaction)
        await transaction.finish()
        feedback = hasFullUnlock ? .status("Purchase complete.") : nil
    }

    private func applyFullUnlock(from transaction: Transaction) {
        guard transaction.productID == Self.fullUnlockProductID else { return }
        guard transaction.revocationDate == nil else { return }

        entitlements.update(fullUnlock: true)
    }
}
