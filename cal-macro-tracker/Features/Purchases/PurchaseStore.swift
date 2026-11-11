import Foundation
import Observation
import os
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

struct EntitlementSnapshot {
    let resolution: EntitlementResolution
    var subscriptionStatuses: [String: ProSubscriptionStatus] = [:]
}

private struct ProductLoadTimeout: Error {}

private actor ProductLoadRace<Value: Sendable> {
    private var continuation: CheckedContinuation<Value?, Never>?

    func wait(
        request: Task<Value, Error>,
        timeout: Duration
    ) async -> Value? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            Task {
                let value = try? await request.value
                await resolve(value)
            }
            Task {
                try? await Task.sleep(for: timeout)
                await resolve(nil)
            }
        }
    }

    private func resolve(_ value: Value?) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: value)
    }
}

@MainActor
@Observable
final class PurchaseStore {
    static let legacyFullUnlockProductID = "fullunlock001"
    private static let productLoadAttempts = 3
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MACROS", category: "Purchases")

    enum Feedback {
        case error(String)
        case status(String)
    }

    private let entitlements: AppEntitlements
    private let entitlementSource: @MainActor () async -> EntitlementSnapshot
    private let purchaseProduct: @MainActor (Product) async throws -> Product.PurchaseResult
    private let productSource: @MainActor () async throws -> [Product]
    private let productRetryDelay: @MainActor (Int) async -> Void
    private let productDiagnostics: @MainActor ([String], [String], String) async -> Void
    private let productLoadTimeout: Duration
    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?
    @ObservationIgnored private var subscriptionStatusUpdatesTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<EntitlementResolution, Never>?
    @ObservationIgnored private var needsAnotherRefresh = false
    @ObservationIgnored private var productLoadTask: Task<Void, Never>?
    @ObservationIgnored private var productRequestTask: Task<[Product], Error>?
    @ObservationIgnored private var productDiagnosticsTask: Task<Void, Never>?
    @ObservationIgnored private var productDiagnosticsID: UUID?
    @ObservationIgnored private var productLoadID: UUID?

    private(set) var products: [ProPlan: Product] = [:]
    private(set) var isEligibleForIntroOffer = false
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    private(set) var feedback: Feedback?
    private(set) var subscriptionStatuses: [String: ProSubscriptionStatus] = [:]

    var hasPro: Bool { entitlements.hasPro }

    private var committedResolution: EntitlementResolution {
        EntitlementResolution(
            source: entitlements.proSource, expiration: entitlements.proExpirationDate,
            hasActiveSubscription: entitlements.hasActiveSubscription)
    }

    init(
        entitlements: AppEntitlements,
        entitlementSource: @escaping @MainActor () async -> EntitlementSnapshot = PurchaseStore.readStoreKitEntitlements,
        purchaseProduct: @escaping @MainActor (Product) async throws -> Product.PurchaseResult = { try await $0.purchase() },
        productSource: @escaping @MainActor () async throws -> [Product] = {
            try await Product.products(for: ProPlan.allCases.map(\.productID))
        },
        productRetryDelay: @escaping @MainActor (Int) async -> Void = { retry in
            // Brief backoff gives transient App Store catalog propagation and network failures time to recover.
            try? await Task.sleep(for: .seconds(retry == 1 ? 1 : 3))
        },
        productLoadTimeout: Duration = .seconds(15),
        productDiagnostics: @escaping @MainActor ([String], [String], String) async -> Void = { requested, returned, error in
            let countryCode = await Storefront.current?.countryCode ?? "unknown"
            let environment: String
            if case let .verified(transaction) = try? await AppTransaction.shared {
                environment = String(describing: transaction.environment)
            } else {
                environment = "unknown"
            }
            PurchaseStore.logger.info(
                "Product request requested \(requested, privacy: .public), returned \(returned, privacy: .public), error \(error, privacy: .public), storefront \(countryCode, privacy: .public), environment \(environment, privacy: .public)"
            )
        }
    ) {
        self.entitlements = entitlements
        self.entitlementSource = entitlementSource
        self.purchaseProduct = purchaseProduct
        self.productSource = productSource
        self.productRetryDelay = productRetryDelay
        self.productLoadTimeout = productLoadTimeout
        self.productDiagnostics = productDiagnostics
    }

    deinit {
        transactionUpdatesTask?.cancel()
        subscriptionStatusUpdatesTask?.cancel()
        refreshTask?.cancel()
        productLoadTask?.cancel()
        productRequestTask?.cancel()
        productDiagnosticsTask?.cancel()
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
        refreshTask?.cancel()
        refreshTask = nil
        needsAnotherRefresh = false
        cancelProductLoad()
        transactionUpdatesTask?.cancel()
        subscriptionStatusUpdatesTask?.cancel()
        transactionUpdatesTask = nil
        subscriptionStatusUpdatesTask = nil
    }

    func loadProducts() async {
        guard products.count != ProPlan.allCases.count else { return }
        if let productLoadTask {
            await productLoadTask.value
            return
        }
        let loadID = UUID()
        productLoadID = loadID
        isLoadingProducts = true
        feedback = nil
        let task = Task { [weak self] in
            guard let self else { return }
            await self.requestProducts(loadID: loadID)
        }
        productLoadTask = task
        await task.value
        guard productLoadID == loadID else { return }
        productLoadTask = nil
        productLoadID = nil
        isLoadingProducts = false
    }

    func cancelProductLoad() {
        productLoadID = nil
        productLoadTask?.cancel()
        productLoadTask = nil
        productRequestTask?.cancel()
        productRequestTask = nil
        productDiagnosticsTask?.cancel()
        productDiagnosticsTask = nil
        productDiagnosticsID = nil
        isLoadingProducts = false
    }

    private func requestProducts(loadID: UUID) async {
        let requestedIDs = ProPlan.allCases.map(\.productID)
        var lastError: (any Error)?
        for attempt in 1...Self.productLoadAttempts {
            guard !Task.isCancelled, productLoadID == loadID else { return }
            let returned: [Product]
            do {
                let request = Task { try await self.productSource() }
                productRequestTask = request
                guard
                    let result = await ProductLoadRace<[Product]>().wait(
                        request: request,
                        timeout: productLoadTimeout
                    )
                else {
                    request.cancel()
                    if productRequestTask == request { productRequestTask = nil }
                    throw ProductLoadTimeout()
                }
                if productRequestTask == request { productRequestTask = nil }
                returned = result
                lastError = nil
            } catch {
                guard !Task.isCancelled, productLoadID == loadID else { return }
                returned = []
                lastError = error
            }
            guard !Task.isCancelled, productLoadID == loadID else { return }

            let loaded = Dictionary(
                uniqueKeysWithValues: ProPlan.allCases.compactMap { plan in
                    returned.first(where: { $0.id == plan.productID }).map { (plan, $0) }
                })
            products.merge(loaded, uniquingKeysWith: { _, new in new })
            let returnedIDs = returned.map(\.id)
            let errorDescription = String(describing: lastError)
            Self.logger.info(
                "Product request attempt \(attempt, privacy: .public), requested \(requestedIDs, privacy: .public), returned \(returnedIDs, privacy: .public), error \(errorDescription, privacy: .public)"
            )
            if productDiagnosticsTask == nil {
                // A cancelled load's diagnostics may finish after a newer load started its own; only clear our handle.
                let diagnosticsID = UUID()
                productDiagnosticsID = diagnosticsID
                productDiagnosticsTask = Task {
                    await productDiagnostics(requestedIDs, returnedIDs, errorDescription)
                    guard productDiagnosticsID == diagnosticsID else { return }
                    productDiagnosticsTask = nil
                    productDiagnosticsID = nil
                }
            }

            if products.count == ProPlan.allCases.count {
                await refreshIntroEligibility()
                guard !Task.isCancelled, productLoadID == loadID else { return }
                feedback = nil
                return
            }
            if attempt < Self.productLoadAttempts {
                await productRetryDelay(attempt)
                guard !Task.isCancelled, productLoadID == loadID else { return }
            }
        }
        await refreshIntroEligibility()
        guard !Task.isCancelled, productLoadID == loadID else { return }
        feedback =
            lastError == nil
            ? .error("Some purchase options are unavailable. Please try again.")
            : .error("Unable to load purchase options. Please try again.")
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
            switch try await purchaseProduct(product) {
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    feedback = .error("Purchase could not be verified.")
                    return
                }
                let resolution = await refreshEntitlements()
                await transaction.finish()
                feedback =
                    resolution.hasPro ? .status("Purchase complete.") : .error("Purchase has not granted access. Please restore purchases.")
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
            let resolution = await refreshEntitlements()
            feedback = .status(resolution.hasPro ? "Purchases restored." : "No Pro purchases were found for this Apple Account.")
        } catch {
            feedback = .error("Restore could not be completed.")
        }
    }

    @discardableResult
    func refreshEntitlements() async -> EntitlementResolution {
        if let refreshTask {
            needsAnotherRefresh = true
            return await refreshTask.value
        }
        let task = Task { await drainEntitlementRefreshes() }
        refreshTask = task
        return await task.value
    }

    private func drainEntitlementRefreshes() async -> EntitlementResolution {
        // Requests arriving during a read dirty the shared task rather than
        // starting a competing scan. Every waiter receives the final commit.
        repeat {
            needsAnotherRefresh = false
            let snapshot = await entitlementSource()
            guard !Task.isCancelled else { return committedResolution }
            let introEligibility = await products[.yearly]?.subscription?.isEligibleForIntroOffer ?? false
            guard !Task.isCancelled else { return committedResolution }
            if needsAnotherRefresh { continue }
            subscriptionStatuses = snapshot.subscriptionStatuses
            entitlements.update(snapshot.resolution)
            isEligibleForIntroOffer = introEligibility
            refreshTask = nil
            return snapshot.resolution
        } while true
    }

    private static func readStoreKitEntitlements() async -> EntitlementSnapshot {
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
        return EntitlementSnapshot(resolution: AppEntitlements.resolve(from: facts), subscriptionStatuses: statuses)
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
