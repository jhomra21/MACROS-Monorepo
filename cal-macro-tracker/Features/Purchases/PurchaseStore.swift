import Foundation
import Observation
import StoreKit

enum ProPlan: String, CaseIterable, Identifiable {
    case yearly, monthly, lifetime

    var id: Self { self }

    var productID: String {
        switch self {
        case .yearly: "macros.pro.yearly"
        case .monthly: "macros.pro.monthly"
        case .lifetime: "macros.pro.lifetime"
        }
    }

    var title: String {
        rawValue.capitalized
    }
}

@MainActor
@Observable
final class PurchaseStore {
    static let legacyFullUnlockProductID = "fullunlock001"

    enum Feedback {
        case error(String)
        case status(String)
    }

    private let entitlements: AppEntitlements
    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?
    @ObservationIgnored private var subscriptionStatusUpdatesTask: Task<Void, Never>?
    @ObservationIgnored private var entitlementRefreshID = 0

    private(set) var products: [ProPlan: Product] = [:]
    private(set) var isEligibleForIntroOffer = false
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    private(set) var feedback: Feedback?
    private(set) var subscriptionStatuses: [String: ProSubscriptionStatus] = [:]

    var hasPro: Bool { entitlements.hasPro }

    init(entitlements: AppEntitlements) {
        self.entitlements = entitlements
    }

    deinit {
        transactionUpdatesTask?.cancel()
        subscriptionStatusUpdatesTask?.cancel()
    }

    func start() async {
        guard transactionUpdatesTask == nil else { return }
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                await self?.handle(transactionResult: result)
            }
        }
        subscriptionStatusUpdatesTask = Task { [weak self] in
            for await _ in Product.SubscriptionInfo.Status.updates {
                guard !Task.isCancelled else { return }
                await self?.refreshEntitlements()
            }
        }
        await refreshEntitlements()
    }

    func stop() {
        entitlementRefreshID += 1
        transactionUpdatesTask?.cancel()
        subscriptionStatusUpdatesTask?.cancel()
        transactionUpdatesTask = nil
        subscriptionStatusUpdatesTask = nil
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: ProPlan.allCases.map(\.productID))
            products = Dictionary(
                uniqueKeysWithValues: ProPlan.allCases.compactMap { plan in
                    loaded.first(where: { $0.id == plan.productID }).map { (plan, $0) }
                })
            await refreshIntroEligibility()
            feedback =
                products.count == ProPlan.allCases.count
                ? nil : .error("Some purchase options are unavailable. Please try again.")
        } catch {
            feedback = .error("Unable to load purchase options. Please try again.")
        }
    }

    func purchase(_ plan: ProPlan) async {
        guard !isPurchasing, !isRestoring else { return }
        isPurchasing = true
        feedback = nil
        defer { isPurchasing = false }
        if products[plan] == nil {
            await loadProducts()
        }
        guard let product = products[plan] else {
            feedback = .error("Purchase is currently unavailable. Please try again.")
            return
        }
        do {
            switch try await product.purchase() {
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    feedback = .error("Purchase could not be verified.")
                    return
                }
                await refreshEntitlements()
                await transaction.finish()
                feedback = hasPro ? .status("Purchase complete.") : .error("Purchase has not granted access. Please restore purchases.")
            case .userCancelled:
                break
            case .pending:
                feedback = .status("Purchase is pending approval. Pro will unlock once approved.")
            @unknown default:
                feedback = .error("Purchase could not be completed.")
            }
        } catch StoreKitError.userCancelled {
            // Cancellation is not a purchase failure and must never grant access.
        } catch {
            feedback = .error("Purchase could not be completed.")
        }
    }

    func restorePurchases() async {
        guard !isPurchasing, !isRestoring else { return }
        isRestoring = true
        feedback = nil
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            feedback = .status(hasPro ? "Purchases restored." : "No Pro purchases were found for this Apple Account.")
        } catch {
            feedback = .error("Restore could not be completed.")
        }
    }

    func refreshEntitlements() async {
        entitlementRefreshID += 1
        let refreshID = entitlementRefreshID
        var currentTransactions: [(transaction: Transaction, isVerified: Bool)] = []
        for await result in Transaction.currentEntitlements {
            switch result {
            case let .verified(transaction):
                currentTransactions.append((transaction, true))
            case let .unverified(transaction, _):
                currentTransactions.append((transaction, false))
            }
        }
        var renewalStates: [UInt64: Product.SubscriptionInfo.RenewalState] = [:]
        var statuses: [String: ProSubscriptionStatus] = [:]
        var statusDates: [String: Date] = [:]
        var statusAccess: [String: Bool] = [:]
        for await group in Product.SubscriptionInfo.Status.all {
            for status in group.statuses {
                guard case let .verified(transaction) = status.transaction,
                    case let .verified(renewal) = status.renewalInfo,
                    transaction.productType == .autoRenewable,
                    ProSource(productID: transaction.productID)?.isSubscription == true
                else { continue }
                renewalStates[transaction.originalID] = status.state
                let grantsAccess = status.state == .subscribed || status.state == .inGracePeriod
                let productID = transaction.productID
                // A family-shared active status outranks an expired personal status.
                if let existingAccess = statusAccess[productID] {
                    if existingAccess && !grantsAccess { continue }
                    if existingAccess == grantsAccess, let date = statusDates[productID], date >= renewal.signedDate { continue }
                }
                statuses[productID] = .resolve(
                    state: status.state, willAutoRenew: renewal.willAutoRenew,
                    expiration: transaction.expirationDate, graceExpiration: renewal.gracePeriodExpirationDate)
                statusDates[productID] = renewal.signedDate
                statusAccess[productID] = grantsAccess
            }
        }
        let facts = currentTransactions.map { transaction, isVerified in
            EntitlementFact(
                productID: transaction.productID, productType: transaction.productType,
                isVerified: isVerified, revocationDate: transaction.revocationDate,
                expirationDate: transaction.expirationDate, isUpgraded: transaction.isUpgraded,
                renewalState: renewalStates[transaction.originalID])
        }
        guard !Task.isCancelled, refreshID == entitlementRefreshID else { return }
        subscriptionStatuses = statuses
        entitlements.update(AppEntitlements.resolve(from: facts))
        await refreshIntroEligibility()
    }

    #if DEBUG
    func setDebugPro(_ isUnlocked: Bool) {
        entitlements.update(EntitlementResolution(source: isUnlocked ? .lifetime : nil, expiration: nil, hasActiveSubscription: false))
        feedback = nil
    }
    #endif

    private func refreshIntroEligibility() async {
        isEligibleForIntroOffer = await products[.yearly]?.subscription?.isEligibleForIntroOffer ?? false
    }

    private func handle(transactionResult result: VerificationResult<Transaction>) async {
        guard case let .verified(transaction) = result,
            ProSource(productID: transaction.productID) != nil
        else { return }
        await refreshEntitlements()
        await transaction.finish()
    }
}
