import StoreKit
import SwiftUI

enum ProPaywallContext: String, CaseIterable, Identifiable {
    case insights, ringColors, weightTrends, healthWeightImport, backup, reminders, general

    var id: Self { self }

    var title: String {
        switch self {
        case .insights: "Nutrition insights"
        case .ringColors: "Custom macro ring colors"
        case .weightTrends: "Weight trends"
        case .healthWeightImport: "Weight import from Apple Health"
        case .backup: "Backup export and import"
        case .reminders: "Multiple reminders"
        case .general: ProLegalLinks.name
        }
    }

    var symbol: String {
        switch self {
        case .insights: "chart.xyaxis.line"
        case .ringColors: "paintpalette"
        case .weightTrends: "scalemass"
        case .healthWeightImport: "heart.text.square"
        case .backup: "arrow.down.doc"
        case .reminders: "bell.badge"
        case .general: "sparkles"
        }
    }

    var benefits: [Self] {
        let all: [Self] = [.insights, .weightTrends, .healthWeightImport, .backup, .ringColors, .reminders]
        return self == .general ? all : [self] + all.filter { $0 != self }
    }
}

struct ProPaywallSheet: View {
    let context: ProPaywallContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.isProPaywallPresented) private var isProPaywallPresented = false
    @Environment(PurchaseStore.self) private var store
    @Environment(AppEntitlements.self) private var entitlements
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPlan = ProPlan.yearly
    @State private var isRedeeming = false
    @State private var successFeedbackToken = 0
    @State private var successAnimationToken = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if store.hasPro {
                        ProPurchaseSuccessView(
                            context: context,
                            activation: activationDescription,
                            animationToken: successAnimationToken,
                            reduceMotion: reduceMotion,
                            dismiss: { dismiss() }
                        )
                        .transition(successTransition)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                        Text(ProLegalLinks.name)
                            .font(.title.bold())
                        Text("See your progress. Make it yours.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(context.benefits) { benefit in
                                Label(benefit.title, systemImage: benefit.symbol)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !store.hasPro {
                        GlassEffectContainer(spacing: 12) {
                            VStack(spacing: 12) {
                                ForEach(ProPlan.allCases) { plan in
                                    planRow(plan)
                                }
                            }
                        }
                    }
                    if !store.hasPro || store.feedback.isError {
                        PurchaseFeedbackText(feedback: store.feedback)
                    }
                    if !store.hasPro {
                        if store.products.count != ProPlan.allCases.count && !store.isLoadingProducts {
                            Button("Retry Purchase Options") {
                                Task { await store.loadProducts() }
                            }
                        }
                        AppAccentActionButton(
                            title: purchaseTitle,
                            systemImage: "lock.open.fill",
                            isCompact: false,
                            isDisabled: isBusy || store.products[selectedPlan] == nil
                        ) {
                            Task { await store.purchase(selectedPlan) }
                        }
                        Button("Restore Purchases") {
                            Task { await store.restorePurchases() }
                        }
                        .disabled(isBusy)
                        Button("Redeem Code") { isRedeeming = true }
                            .disabled(isBusy)
                        legalFooter
                    }
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .animation(reduceMotion ? nil : .smooth, value: store.hasPro)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await store.loadProducts() }
            .offerCodeRedemption(isPresented: $isRedeeming)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { isProPaywallPresented = true }
        .onDisappear { isProPaywallPresented = false }
        .onChange(of: store.hasPro) { wasPro, isPro in
            guard !wasPro, isPro else { return }
            withAnimation(reduceMotion ? nil : .smooth) {
                successAnimationToken += 1
            }
            successFeedbackToken += 1
        }
        .sensoryFeedback(.success, trigger: successFeedbackToken)
    }

    private var isBusy: Bool { store.isPurchasing || store.isRestoring }

    private var successTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98))
    }

    private var activationDescription: String {
        switch entitlements.proSource {
        case .lifetime, .legacyFullUnlock:
            return "Lifetime access"
        case .yearly, .monthly:
            let plan: ProPlan = entitlements.proSource == .yearly ? .yearly : .monthly
            let status = store.subscriptionStatuses[plan.productID] ?? .active
            let detail: String
            if status == .active, let expiration = entitlements.proExpirationDate {
                detail = "Through \(expiration.formatted(date: .abbreviated, time: .omitted))"
            } else {
                detail = status.text
            }
            return "\(plan.title) · \(detail)"
        case nil:
            return "Pro access"
        }
    }

    private var hasYearlyTrial: Bool {
        store.isEligibleForIntroOffer
            && store.products[.yearly]?.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    private func planRow(_ plan: ProPlan) -> some View {
        Button {
            selectedPlan = plan
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: selectedPlan == plan ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedPlan == plan ? Color.accentColor : .secondary)
                            Text(plan.title).font(.headline)
                        }
                        if plan == .yearly {
                            Text(hasYearlyTrial ? "7 days free · Best value" : "Best value")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                        Text(store.products[plan].map { $0.proPrice } ?? "Unavailable")
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: selectedPlan == plan ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedPlan == plan ? Color.accentColor : .secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.title).font(.headline)
                            if plan == .yearly {
                                Text(hasYearlyTrial ? "7 days free · Best value" : "Best value")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        Spacer()
                        Text(store.products[plan].map { $0.proPrice } ?? "Unavailable")
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .padding(16)
            .contentShape(RoundedRectangle(cornerRadius: 20))
            .appGlassRoundedRect(cornerRadius: 20)
        }
        .buttonStyle(.plain)
        .disabled(isBusy || store.products[plan] == nil)
        .accessibilityLabel("\(plan.title), \(store.products[plan]?.proPrice ?? "Unavailable")")
        .accessibilityValue(selectedPlan == plan ? "Selected" : "Not selected")
        .accessibilityIdentifier("pro.plan.\(plan.rawValue)")
    }

    private var purchaseTitle: String {
        if store.isPurchasing { return "Purchasing…" }
        if store.isLoadingProducts { return "Loading…" }
        guard let product = store.products[selectedPlan] else { return "Purchase Unavailable" }
        if selectedPlan == .yearly && hasYearlyTrial { return "Start 7-day free trial" }
        return selectedPlan == .lifetime ? "Buy lifetime for \(product.displayPrice)" : "Subscribe for \(product.proPrice)"
    }

    private var legalFooter: some View {
        VStack(spacing: 10) {
            if selectedPlan == .yearly && hasYearlyTrial, let product = store.products[.yearly] {
                Text("7 days free, then \(product.proPrice).")
            }
            Text(
                "Payment is charged to your Apple Account at confirmation, or after your free trial. Subscriptions automatically renew unless canceled at least 24 hours before the current period ends. Manage or cancel in your Apple Account settings. Lifetime is a one-time purchase."
            )
            HStack {
                Link("Terms of Use", destination: ProLegalLinks.terms)
                Link("Privacy Policy", destination: ProLegalLinks.privacy)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
}

private struct ProPurchaseSuccessView: View {
    let context: ProPaywallContext
    let activation: String
    let animationToken: Int
    let reduceMotion: Bool
    let dismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if reduceMotion {
                successMark
            } else {
                successMark
                    .symbolEffect(.bounce, value: animationToken)
            }
        }
        .accessibilityHidden(true)
        Text("You’re all set")
            .font(.title.bold())
        Text("Welcome to \(ProLegalLinks.name)")
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        Text(activation)
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(context.benefits) { benefit in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    Text(benefit.title)
                        .foregroundStyle(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        AppAccentActionButton(
            title: actionTitle,
            systemImage: "arrow.right",
            isCompact: false,
            isDisabled: false,
            action: dismiss
        )
    }

    private var successMark: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 52, weight: .semibold))
            .foregroundStyle(Color.accentColor)
    }

    private var actionTitle: String {
        guard dynamicTypeSize.isAccessibilitySize else {
            return context == .general ? "Start using Pro" : "Open \(context.title)"
        }
        return switch context {
        case .insights: "Open Insights"
        case .ringColors: "Open Ring colors"
        case .weightTrends: "Open Weight trends"
        case .healthWeightImport: "Open Health import"
        case .backup: "Open Backup"
        case .reminders: "Open Reminders"
        case .general: "Start Pro"
        }
    }
}

extension Product {
    var proPrice: String {
        guard let period = subscription?.subscriptionPeriod else { return "\(displayPrice) once" }
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: return displayPrice
        }
        return "\(displayPrice)/\(period.value == 1 ? "" : "\(period.value) ")\(unit)"
    }
}

struct PurchaseFeedbackText: View {
    let feedback: PurchaseStore.Feedback?

    var body: some View {
        switch feedback {
        case let .error(message):
            Text(message).font(.footnote).foregroundStyle(.red)
        case let .status(message):
            Text(message).font(.footnote).foregroundStyle(.secondary)
        case nil:
            EmptyView()
        }
    }
}

private extension PurchaseStore.Feedback? {
    var isError: Bool {
        if case .error? = self { true } else { false }
    }
}
