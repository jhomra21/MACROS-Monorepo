import StoreKit
import SwiftUI

struct ProSettingsSection: View {
    @Environment(PurchaseStore.self) private var store
    @Environment(AppEntitlements.self) private var entitlements
    @Binding var paywallContext: ProPaywallContext?
    @State private var isManaging = false
    @State private var isRedeeming = false

    var body: some View {
        Section {
            Button {
                paywallContext = .general
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ProBrand.name)
                        Text(status).font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: store.hasPro ? "checkmark.seal.fill" : "chevron.right")
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if entitlements.proSource?.isSubscription == true {
                Button("Manage Subscription") { isManaging = true }
            }
            Button("Restore Purchases") {
                Task { await store.restorePurchases() }
            }
            .disabled(store.isPurchasing || store.isRestoring)
            Button("Redeem Code") { isRedeeming = true }
                .disabled(store.isPurchasing || store.isRestoring)
            PurchaseFeedbackText(feedback: store.feedback)
            #if DEBUG
            Button(store.hasPro ? "Revoke Debug Pro" : "Grant Debug Pro") {
                store.setDebugPro(!store.hasPro)
            }
            #endif
        } footer: {
            Text("Purchases are processed by Apple. Restore anytime with the same Apple Account.")
        }
        .manageSubscriptionsSheet(isPresented: $isManaging)
        .offerCodeRedemption(isPresented: $isRedeeming)
        .onChange(of: isManaging) { _, presented in
            if !presented { Task { await store.refreshEntitlements() } }
        }
    }

    private var status: String {
        switch entitlements.proSource {
        case .yearly, .monthly:
            let plan = entitlements.proSource == .yearly ? "Yearly" : "Monthly"
            if let expiration = entitlements.proExpirationDate {
                return "Pro \(plan) · renews \(expiration.formatted(date: .abbreviated, time: .omitted))"
            }
            return "Pro \(plan)"
        case .lifetime: return "Pro Lifetime"
        case .legacyFullUnlock: return "Full Unlock (legacy)"
        case nil: return "Free"
        }
    }
}
