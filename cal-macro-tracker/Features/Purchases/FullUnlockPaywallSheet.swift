import StoreKit
import SwiftUI

struct FullUnlockPaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseStore.self) private var purchaseStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Spacer(minLength: 8)

                Image(systemName: purchaseStore.hasFullUnlock ? "checkmark.seal.fill" : "sparkles")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(purchaseStore.hasFullUnlock ? .green : .accentColor)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(purchaseStore.hasFullUnlock ? "Full App Unlocked" : "Unlock All Features")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text("Customize premium app features with one purchase.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text("Purchases are processed by Apple. Restore anytime with the same Apple ID.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let errorMessage = purchaseStore.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    GlassEffectContainer(spacing: 12) {
                        if purchaseStore.hasFullUnlock {
                            AppAccentActionButton(title: "Done", systemImage: "checkmark", isCompact: false) {
                                dismiss()
                            }
                        } else {
                            let isPurchaseDisabled = purchaseStore.isPurchasing || purchaseStore.isLoadingProducts

                            AppAccentActionButton(
                                title: purchaseButtonTitle,
                                systemImage: "lock.open.fill",
                                isCompact: false,
                                isDisabled: isPurchaseDisabled
                            ) {
                                Task {
                                    await purchaseStore.purchaseFullUnlock()
                                    if purchaseStore.hasFullUnlock {
                                        dismiss()
                                    }
                                }
                            }
                        }
                    }

                    Button("Restore Purchases") {
                        Task {
                            await purchaseStore.restorePurchases()
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(purchaseStore.isPurchasing)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 8)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await purchaseStore.loadProducts()
            }
        }
    }

    private var purchaseButtonTitle: String {
        if purchaseStore.isPurchasing {
            return "Purchasing…"
        }

        if purchaseStore.isLoadingProducts {
            return "Loading…"
        }

        if let product = purchaseStore.fullUnlockProduct {
            return "Unlock for \(product.displayPrice)"
        }

        return "Unlock"
    }
}
