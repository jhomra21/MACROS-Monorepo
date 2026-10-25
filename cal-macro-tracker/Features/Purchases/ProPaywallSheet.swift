import StoreKit
import SwiftUI

enum ProPaywallContext: String, CaseIterable, Identifiable {
    case insights, ringColors, weightTrends, healthSync, backup, reminders, general

    var id: Self { self }

    var title: String {
        switch self {
        case .insights: "Nutrition insights"
        case .ringColors: "Custom macro ring colors"
        case .weightTrends: "Weight trends"
        case .healthSync: "Apple Health sync"
        case .backup: "Backup export and import"
        case .reminders: "Multiple reminders"
        case .general: ProBrand.name
        }
    }

    var symbol: String {
        switch self {
        case .insights: "chart.xyaxis.line"
        case .ringColors: "paintpalette"
        case .weightTrends: "scalemass"
        case .healthSync: "heart.text.square"
        case .backup: "arrow.down.doc"
        case .reminders: "bell.badge"
        case .general: "sparkles"
        }
    }

    var benefits: [Self] {
        let all: [Self] = [.insights, .weightTrends, .healthSync, .backup, .ringColors, .reminders]
        return self == .general ? all : [self] + all.filter { $0 != self }
    }
}

struct ProPaywallSheet: View {
    let context: ProPaywallContext
    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseStore.self) private var store
    @State private var selectedPlan = ProPlan.yearly
    @State private var isRedeeming = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: store.hasPro ? "checkmark.seal.fill" : "sparkles")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    Text(ProBrand.name)
                        .font(.title.bold())
                    Text(store.hasPro ? "Your Pro features are ready." : "See your progress. Make it yours.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(context.benefits) { benefit in
                            Label(benefit.title, systemImage: benefit.symbol)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !store.hasPro {
                        GlassEffectContainer(spacing: 12) {
                            VStack(spacing: 12) {
                                ForEach(ProPlan.allCases) { plan in
                                    planRow(plan)
                                }
                            }
                        }
                    }
                    PurchaseFeedbackText(feedback: store.feedback)
                    if store.products.count != ProPlan.allCases.count && !store.isLoadingProducts {
                        Button("Retry Purchase Options") {
                            Task { await store.loadProducts() }
                        }
                    }
                    AppAccentActionButton(
                        title: store.hasPro ? "Done" : purchaseTitle,
                        systemImage: store.hasPro ? "checkmark" : "lock.open.fill",
                        isCompact: false,
                        isDisabled: !store.hasPro && (isBusy || store.products[selectedPlan] == nil)
                    ) {
                        if store.hasPro {
                            dismiss()
                        } else {
                            Task { await store.purchase(selectedPlan) }
                        }
                    }
                    Button("Restore Purchases") {
                        Task { await store.restorePurchases() }
                    }
                    .disabled(isBusy)
                    Button("Redeem Code") { isRedeeming = true }
                        .disabled(isBusy)
                    legalFooter
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await store.loadProducts() }
            .offerCodeRedemption(isPresented: $isRedeeming)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var isBusy: Bool { store.isPurchasing || store.isRestoring }

    private var hasYearlyTrial: Bool {
        store.isEligibleForIntroOffer
            && store.products[.yearly]?.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    private func planRow(_ plan: ProPlan) -> some View {
        Button {
            selectedPlan = plan
        } label: {
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
