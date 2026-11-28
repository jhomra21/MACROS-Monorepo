import StoreKit
import SwiftUI

enum ProPaywallContext: String, CaseIterable, Identifiable {
    case insights, sharingInvites, sharedPersonWidget, ringColors, weightTrends, healthWeightImport, backup, reminders, widgetBackground,
        mealPhoto, general

    var id: Self { self }

    var title: String {
        switch self {
        case .insights: "Nutrition insights"
        case .sharingInvites: "Sharing circle invites"
        case .sharedPersonWidget: "Shared-person widgets"
        case .ringColors: "Custom macro ring colors"
        case .weightTrends: "Weight trends"
        case .healthWeightImport: "Weight import from Apple Health"
        case .backup: "Backup export and import"
        case .reminders: "Multiple reminders"
        case .widgetBackground: "Widget backgrounds"
        case .mealPhoto: "Meal photo scanning"
        case .general: ProLegalLinks.name
        }
    }

    var benefits: [Self] {
        let all: [Self] = [
            .insights, .sharingInvites, .sharedPersonWidget, .weightTrends, .healthWeightImport, .backup, .ringColors, .widgetBackground,
            .reminders, .mealPhoto
        ]
        return self == .general ? all : [self] + all.filter { $0 != self }
    }
}

struct ProPaywallSheet: View {
    static func planPriceLabel(isLoading: Bool, price: String?) -> String {
        price ?? (isLoading ? "Loading…" : "Unavailable")
    }

    let context: ProPaywallContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.isProPaywallPresented) private var isProPaywallPresented = false
    @Environment(PurchaseStore.self) private var store
    @State private var successFeedbackToken = 0

    var body: some View {
        NavigationStack {
            ProPaywallContent(context: context, onContinue: nil, onSuccessDone: { dismiss() })
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", role: .close) { dismiss() }
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { isProPaywallPresented = true }
        .onDisappear {
            isProPaywallPresented = false
            store.cancelProductLoad()
        }
        .onChange(of: store.hasPro) { wasPro, isPro in
            guard !wasPro, isPro else { return }
            successFeedbackToken += 1
        }
        .sensoryFeedback(.success, trigger: successFeedbackToken)
    }
}

struct ProPaywallContent: View {
    let context: ProPaywallContext
    let onContinue: (() -> Void)?
    let onSuccessDone: (() -> Void)?
    @Environment(PurchaseStore.self) private var store
    @Environment(AppEntitlements.self) private var entitlements
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPlan = ProPlan.yearly
    @State private var isRedeeming = false
    @State private var successAnimationToken = 0

    private var isBusy: Bool { store.isPurchasing || store.isRestoring }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if store.hasPro {
                    ProPurchaseSuccessView(
                        context: context,
                        activation: activationDescription,
                        animationToken: successAnimationToken,
                        reduceMotion: reduceMotion,
                        title: onContinue == nil ? "Done" : "Continue",
                        dismiss: onContinue ?? onSuccessDone ?? {}
                    )
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
                    if store.feedback.isError { PurchaseFeedbackText(feedback: store.feedback) }
                } else {
                    ProPaywallHeader()
                    ProFeatureList(context: context)
                    planPicker
                    purchaseActions
                    linkRow
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .animation(reduceMotion ? nil : .smooth, value: store.hasPro)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(PlatformColors.groupedBackground)
        .task { await store.loadProducts() }
        .offerCodeRedemption(isPresented: $isRedeeming)
        .onChange(of: store.hasPro) { wasPro, isPro in
            guard !wasPro, isPro else { return }
            successAnimationToken += 1
        }
        .sensoryFeedback(.selection, trigger: selectedPlan)
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

    private var yearlyTrialLength: String? {
        guard hasYearlyTrial, let period = store.products[.yearly]?.subscription?.introductoryOffer?.period,
            let unit = period.unitName
        else { return nil }
        return period.unit == .week ? "\(period.value * 7) days" : "\(period.value) \(unit)"
    }

    private func badge(for plan: ProPlan) -> String? {
        guard plan == .yearly else { return nil }
        return yearlyTrialLength.map { "\($0) free" } ?? "Best value"
    }

    private func price(for plan: ProPlan) -> String {
        ProPaywallSheet.planPriceLabel(isLoading: store.isLoadingProducts, price: store.products[plan]?.displayPrice)
    }

    @ViewBuilder
    private var planPicker: some View {
        GlassEffectContainer(spacing: 8) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) { ForEach(ProPlan.allCases) { planOption($0) } }
            } else {
                HStack(spacing: 8) { ForEach(ProPlan.allCases) { planOption($0) } }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selectedPlan)
    }

    private func planOption(_ plan: ProPlan) -> some View {
        let isSelected = selectedPlan == plan
        let badge = badge(for: plan)
        return Button {
            selectedPlan = plan
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    planRowLabel(plan, isSelected: isSelected, badge: badge)
                } else {
                    planTileLabel(plan, isSelected: isSelected, badge: badge)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 20))
            .appGlassRoundedRect(cornerRadius: 20)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy || store.products[plan] == nil)
        .accessibilityLabel("\(plan.title), \(price(for: plan)), \(plan.periodLine)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier("pro.plan.\(plan.rawValue)")
    }

    private func selectionMark(_ isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .contentTransition(.symbolEffect(.replace))
    }

    private func planTileLabel(_ plan: ProPlan, isSelected: Bool, badge: String?) -> some View {
        VStack(spacing: 4) {
            selectionMark(isSelected)
            Text(plan.title).font(.subheadline.weight(.semibold))
            Text(price(for: plan))
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(plan.periodLine).font(.caption).foregroundStyle(.secondary)
            if let badge { ProPlanBadge(text: badge) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }

    private func planRowLabel(_ plan: ProPlan, isSelected: Bool, badge: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                selectionMark(isSelected)
                Text(plan.title).font(.headline)
            }
            if let badge { ProPlanBadge(text: badge) }
            Text("\(price(for: plan)) \(plan.periodLine)")
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private var purchaseTitle: String {
        if store.isPurchasing { return "Purchasing…" }
        if store.isLoadingProducts { return "Loading…" }
        guard let product = store.products[selectedPlan] else { return "Purchase Unavailable" }
        if selectedPlan == .yearly && hasYearlyTrial { return "Start Free Trial" }
        return selectedPlan == .lifetime ? "Buy lifetime for \(product.displayPrice)" : "Subscribe for \(product.proPrice)"
    }

    private var legalNote: String {
        switch selectedPlan {
        case .yearly:
            if let trial = yearlyTrialLength, let product = store.products[.yearly] {
                return "\(trial) free, then \(product.proPrice). Renews automatically until canceled."
            }
            return "Renews automatically until canceled. Cancel anytime in Settings."
        case .monthly:
            return "Renews automatically until canceled. Cancel anytime in Settings."
        case .lifetime:
            return "One-time purchase."
        }
    }

    private var purchaseActions: some View {
        VStack(spacing: 8) {
            PurchaseFeedbackText(feedback: store.feedback)
            if store.products.count != ProPlan.allCases.count && !store.isLoadingProducts {
                Button("Retry") { Task { await store.loadProducts() } }
                    .frame(minHeight: 44)
            }
            AppAccentActionButton(
                title: purchaseTitle, systemImage: "lock.open.fill", isCompact: false,
                isDisabled: isBusy || store.products[selectedPlan] == nil
            ) {
                Task { await store.purchase(selectedPlan) }
            }
            if let onContinue {
                Button("Continue with Free", action: onContinue)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            Text(legalNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var linkRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                legalLinks; accountActions
            }
            VStack(spacing: 0) {
                HStack(spacing: 14) { legalLinks }
                HStack(spacing: 14) { accountActions }
            }
        }
        .font(.caption)
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private var legalLinks: some View {
        Link("Terms of Use", destination: ProLegalLinks.terms)
        Link("Privacy Policy", destination: ProLegalLinks.privacy)
    }

    @ViewBuilder
    private var accountActions: some View {
        Button("Restore Purchases") { Task { await store.restorePurchases() } }
            .disabled(isBusy)
        Button("Redeem Code") { isRedeeming = true }
            .disabled(isBusy)
    }
}

private extension ProPlan {
    var periodLine: String {
        switch self {
        case .yearly: "per year"
        case .monthly: "per month"
        case .lifetime: "one time"
        }
    }
}

private struct ProPlanBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accentColor, in: Capsule())
    }
}

private struct ProPaywallHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let layout = isStacked ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 14))
        layout {
            ProRingsMark().accessibilityHidden(true)
            VStack(alignment: isStacked ? .center : .leading, spacing: 2) {
                Text("MACROS Pro").font(.title.bold())
                Text("Your food diary stays free.").font(.subheadline).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(isStacked ? .center : .leading)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProRingsMark: View {
    private static let rings: [(metric: MacroMetric, progress: Double)] = [
        (.protein, 0.78), (.carbs, 0.62), (.fat, 0.88)
    ]
    @ScaledMetric(relativeTo: .title) private var diameter: CGFloat = 52

    var body: some View {
        ZStack {
            ForEach(Array(Self.rings.enumerated()), id: \.offset) { index, ring in
                let color = MacroRingPalette.standard.color(for: ring.metric)
                let size = diameter - CGFloat(index) * diameter * 0.3
                Circle().stroke(color.opacity(0.2), lineWidth: diameter * 0.07)
                    .frame(width: size, height: size)
                Circle().trim(from: 0, to: ring.progress)
                    .stroke(color, style: StrokeStyle(lineWidth: diameter * 0.07, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size, height: size)
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct ProFeature: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let color: Color
    let contexts: [ProPaywallContext]

    static let all = [
        ProFeature(id: "mealPhoto", title: "Meal photo scanning", symbol: "fork.knife", color: .orange, contexts: [.mealPhoto]),
        ProFeature(
            id: "insights", title: "Insights beyond 7 days", symbol: "chart.xyaxis.line", color: .blue, contexts: [.insights]),
        ProFeature(
            id: "sharing", title: "Sharing circle and friend widgets", symbol: "person.2.fill", color: .pink,
            contexts: [.sharingInvites, .sharedPersonWidget]),
        ProFeature(
            id: "weight", title: "Weight trends and Health import", symbol: "scalemass.fill", color: .red,
            contexts: [.weightTrends, .healthWeightImport]),
        ProFeature(id: "reminders", title: "Up to 3 reminders", symbol: "bell.badge.fill", color: .green, contexts: [.reminders]),
        ProFeature(
            id: "customize", title: "Ring colors, widget backgrounds, backup", symbol: "paintpalette.fill", color: .purple,
            contexts: [.ringColors, .widgetBackground, .backup])
    ]
}

private struct ProFeatureList: View {
    let context: ProPaywallContext
    @ScaledMetric(relativeTo: .subheadline) private var iconSize: CGFloat = 28

    private var features: [ProFeature] {
        let matching = ProFeature.all.filter { $0.contexts.contains(context) }
        return matching + ProFeature.all.filter { !$0.contexts.contains(context) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(features) { feature in
                let isHighlighted = feature.contexts.contains(context)
                HStack(spacing: 12) {
                    Image(systemName: feature.symbol)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: iconSize, height: iconSize)
                        .background(feature.color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .accessibilityHidden(true)
                    Text(feature.title)
                        .font(.subheadline.weight(isHighlighted ? .semibold : .regular))
                        .foregroundStyle(isHighlighted ? Color.accentColor : .primary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardBackground(cornerRadius: 20)
    }
}

private struct ProPurchaseSuccessView: View {
    let context: ProPaywallContext
    let activation: String
    let animationToken: Int
    let reduceMotion: Bool
    let title: String
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            if reduceMotion {
                successMark
            } else {
                successMark.symbolEffect(.bounce, value: animationToken)
            }
            Text("You’re all set").font(.title.bold())
            Text("Welcome to \(ProLegalLinks.name)")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(activation)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(context.benefits) { benefit in
                    Label(benefit.title, systemImage: "checkmark.circle.fill")
                        .labelStyle(ProSuccessLabelStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            AppAccentActionButton(
                title: title, systemImage: "arrow.right", isCompact: false, isDisabled: false, action: dismiss
            )
        }
        .accessibilityElement(children: .contain)
    }

    private var successMark: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 52, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .accessibilityHidden(true)
    }
}

private struct ProSuccessLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon.foregroundStyle(Color.accentColor)
            configuration.title.foregroundStyle(.primary)
        }
    }
}

extension Product {
    var proPrice: String {
        guard let period = subscription?.subscriptionPeriod else { return "\(displayPrice) once" }
        guard let unit = period.unitName else { return displayPrice }
        return "\(displayPrice)/\(period.value == 1 ? "" : "\(period.value) ")\(unit)"
    }
}

extension Product.SubscriptionPeriod {
    var unitName: String? {
        switch unit {
        case .day: value == 1 ? "day" : "days"
        case .week: value == 1 ? "week" : "weeks"
        case .month: value == 1 ? "month" : "months"
        case .year: value == 1 ? "year" : "years"
        @unknown default: nil
        }
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
