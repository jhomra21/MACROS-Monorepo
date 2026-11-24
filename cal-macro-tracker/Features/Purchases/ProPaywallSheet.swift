import StoreKit
import SwiftUI

enum ProPaywallContext: String, CaseIterable, Identifiable {
    case insights, sharingInvites, sharedPersonWidget, ringColors, weightTrends, healthWeightImport, backup, reminders, widgetBackground,
        general

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
        case .general: ProLegalLinks.name
        }
    }

    var symbol: String {
        switch self {
        case .insights: "chart.xyaxis.line"
        case .sharingInvites: "person.2"
        case .sharedPersonWidget: "person.crop.rectangle"
        case .ringColors: "paintpalette"
        case .weightTrends: "scalemass"
        case .healthWeightImport: "heart.text.square"
        case .backup: "arrow.down.doc"
        case .reminders: "bell.badge"
        case .widgetBackground: "photo"
        case .general: "sparkles"
        }
    }

    var benefits: [Self] {
        let all: [Self] = [
            .insights, .sharingInvites, .sharedPersonWidget, .weightTrends, .healthWeightImport, .backup, .ringColors, .widgetBackground,
            .reminders
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
                } else {
                    Text("MACROS Pro").font(.largeTitle.bold())
                    Text("Your food diary stays free. Pro adds more.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    ProFeatureCards(context: context)
                }
                if !store.hasPro {
                    GlassEffectContainer(spacing: 12) {
                        VStack(spacing: 12) {
                            ForEach(ProPlan.allCases) { plan in planRow(plan) }
                        }
                        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selectedPlan)
                    }
                }
                if !store.hasPro || store.feedback.isError {
                    PurchaseFeedbackText(feedback: store.feedback)
                }
                if !store.hasPro {
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
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    Button("Restore Purchases") { Task { await store.restorePurchases() } }
                        .frame(minHeight: 44)
                        .disabled(isBusy)
                    Button("Redeem Code") { isRedeeming = true }
                        .frame(minHeight: 44)
                        .disabled(isBusy)
                    legalFooter
                }
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .animation(reduceMotion ? nil : .smooth, value: store.hasPro)
        }
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
        return "\(period.value) \(unit)"
    }

    private var yearlyBadge: String {
        yearlyTrialLength.map { "\($0) free · Best value" } ?? "Best value"
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
                                .contentTransition(.symbolEffect(.replace))
                            Text(plan.title).font(.headline)
                        }
                        if plan == .yearly {
                            Text(yearlyBadge)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                        Text(ProPaywallSheet.planPriceLabel(isLoading: store.isLoadingProducts, price: store.products[plan]?.proPrice))
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: selectedPlan == plan ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedPlan == plan ? Color.accentColor : .secondary)
                            .contentTransition(.symbolEffect(.replace))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.title).font(.headline)
                            if plan == .yearly {
                                Text(yearlyBadge)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        Spacer()
                        Text(ProPaywallSheet.planPriceLabel(isLoading: store.isLoadingProducts, price: store.products[plan]?.proPrice))
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .padding(16)
            .contentShape(RoundedRectangle(cornerRadius: 20))
            .appGlassRoundedRect(cornerRadius: 20)
            .overlay {
                if selectedPlan == plan {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy || store.products[plan] == nil)
        .accessibilityLabel(
            "\(plan.title), \(ProPaywallSheet.planPriceLabel(isLoading: store.isLoadingProducts, price: store.products[plan]?.proPrice))"
        )
        .accessibilityValue(selectedPlan == plan ? "Selected" : "Not selected")
        .accessibilityIdentifier("pro.plan.\(plan.rawValue)")
    }

    private var purchaseTitle: String {
        if store.isPurchasing { return "Purchasing…" }
        if store.isLoadingProducts { return "Loading…" }
        guard let product = store.products[selectedPlan] else { return "Purchase Unavailable" }
        if selectedPlan == .yearly && hasYearlyTrial { return "Start Free Trial" }
        return selectedPlan == .lifetime ? "Buy lifetime for \(product.displayPrice)" : "Subscribe for \(product.proPrice)"
    }

    private var legalFooter: some View {
        VStack(spacing: 10) {
            if selectedPlan == .yearly, let trial = yearlyTrialLength, let product = store.products[.yearly] {
                Text("\(trial) free, then \(product.proPrice).")
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

private struct ProFeatureCards: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let context: ProPaywallContext

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(Array(featureRows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    if row.count == 1 {
                        featureCard(row[0])
                            .gridCellColumns(2)
                    } else {
                        ForEach(row) { feature in
                            featureCard(feature)
                        }
                    }
                }
            }
        }
    }

    private func featureCard(_ feature: ProFeature) -> some View {
        ProFeatureCard(feature: feature, isHighlighted: feature.contexts.contains(context))
            .frame(maxWidth: .infinity)
    }

    private var featureRows: [[ProFeature]] {
        guard !dynamicTypeSize.isAccessibilitySize else { return orderedFeatures.map { [$0] } }
        var rows: [[ProFeature]] = []
        var pair: [ProFeature] = []
        for feature in orderedFeatures {
            if feature.isWide {
                if !pair.isEmpty {
                    rows.append(pair)
                    pair = []
                }
                rows.append([feature])
            } else {
                pair.append(feature)
                if pair.count == 2 {
                    rows.append(pair)
                    pair = []
                }
            }
        }
        if !pair.isEmpty { rows.append(pair) }
        return rows
    }

    private var orderedFeatures: [ProFeature] {
        guard context != .general,
            let matchingIndex = ProFeature.all.firstIndex(where: { $0.contexts.contains(context) })
        else { return ProFeature.all }
        return [ProFeature.all[matchingIndex]]
            + ProFeature.all.enumerated()
            .filter { $0.offset != matchingIndex }
            .map(\.element)
    }
}

private struct ProFeature: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let contexts: [ProPaywallContext]
    var isWide = false
    var visual: Visual = .none

    enum Visual {
        case none, chart, rings
    }

    static let all = [
        ProFeature(
            id: "insights", title: "Insights beyond 7 days", subtitle: "14, 30, 90 days, 1 year, all time",
            symbol: ProPaywallContext.insights.symbol, contexts: [.insights], isWide: true, visual: .chart
        ),
        ProFeature(
            id: "sharing", title: "Sharing circle", subtitle: "Invite people, see their rings",
            symbol: ProPaywallContext.sharingInvites.symbol,
            contexts: [.sharingInvites]
        ),
        ProFeature(
            id: "widgets", title: "Shared widgets", subtitle: "A friend’s rings on your Home Screen",
            symbol: ProPaywallContext.sharedPersonWidget.symbol,
            contexts: [.sharedPersonWidget], visual: .rings
        ),
        ProFeature(
            id: "weight", title: "Weight trends", subtitle: "Plus import from Apple Health",
            symbol: ProPaywallContext.weightTrends.symbol,
            contexts: [.weightTrends, .healthWeightImport]
        ),
        ProFeature(
            id: "reminders", title: "More reminders", subtitle: "Up to three reminders total, including your daily reminder.",
            symbol: ProPaywallContext.reminders.symbol,
            contexts: [.reminders]
        ),
        ProFeature(
            id: "customize", title: "Make it yours",
            subtitle: "Ring colors · widget backgrounds · backup export and import",
            symbol: ProPaywallContext.ringColors.symbol,
            contexts: [.ringColors, .widgetBackground, .backup], isWide: true
        )
    ]
}

private struct ProFeatureCard: View {
    let feature: ProFeature
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: feature.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(iconForeground)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                visual
            }
            Text(feature.title)
                .font(.headline)
                .foregroundStyle(cardForeground)
            Text(feature.subtitle)
                .font(.subheadline)
                .foregroundStyle(usesColoredBackground ? Color.white : Color.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(cardBackground)
        }
        .overlay {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(feature.title), \(feature.subtitle)")
    }

    private var cardBackground: AnyShapeStyle {
        switch feature.id {
        case "insights":
            AnyShapeStyle(
                LinearGradient(
                    colors: [Color(hex: "#0054B8") ?? .blue, Color(hex: "#003F91") ?? .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case "sharing":
            AnyShapeStyle(
                LinearGradient(
                    colors: [Color(hex: "#B00055") ?? .pink, Color(hex: "#79003B") ?? .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case "weight":
            AnyShapeStyle(
                LinearGradient(
                    colors: [Color(hex: "#A04400") ?? .orange, Color(hex: "#713000") ?? .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case "reminders":
            AnyShapeStyle(
                LinearGradient(
                    colors: [Color(hex: "#454B55") ?? .gray, Color(hex: "#282B32") ?? .gray],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case "customize":
            AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(hex: "#315CA8") ?? .blue,
                        Color(hex: "#6A438F") ?? .purple,
                        Color(hex: "#8B4664") ?? .pink
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        default:
            AnyShapeStyle(PlatformColors.cardBackground)
        }
    }

    private var usesColoredBackground: Bool {
        feature.id != "widgets"
    }

    private var cardForeground: Color {
        usesColoredBackground ? .white : .primary
    }

    private var iconForeground: Color {
        feature.id == "widgets" ? MacroRingPalette.standard.protein : cardForeground
    }

    @ViewBuilder
    private var visual: some View {
        switch feature.visual {
        case .none:
            EmptyView()
        case .chart:
            HStack(alignment: .bottom, spacing: 4) {
                let heights: [CGFloat] = [0.35, 0.58, 0.43, 0.76, 0.92]
                ForEach(heights.indices, id: \.self) { index in
                    Capsule()
                        .fill(cardForeground)
                        .frame(width: 8, height: 42 * heights[index])
                }
            }
            .frame(height: 42)
            .accessibilityHidden(true)
        case .rings:
            HStack(spacing: -8) {
                ForEach([MacroMetric.protein, .carbs, .fat], id: \.self) { metric in
                    Circle().trim(from: 0, to: 0.72)
                        .stroke(
                            MacroRingPalette.standard.color(for: metric),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 32, height: 32)
                }
            }
            .accessibilityHidden(true)
        }
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
