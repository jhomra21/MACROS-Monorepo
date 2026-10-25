import SwiftData
import SwiftUI

struct HealthSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppEntitlements.self) private var entitlements
    @Environment(HealthKitService.self) private var health
    @AppStorage(AppStorageKeys.healthNutritionWriteEnabled) private var writeNutrition = false
    @AppStorage(AppStorageKeys.healthWeightReadEnabled) private var readWeight = false
    @State private var paywallContext: ProPaywallContext?

    var body: some View {
        Section("Apple Health") {
            Toggle("Write nutrition to Health", isOn: $writeNutrition)
                .onChange(of: writeNutrition) { _, enabled in
                    NotificationCenter.default.post(name: .healthSettingsDidChange, object: nil)
                    if enabled {
                        Task { try? await health.requestAuthorization(readWeight: readWeight && entitlements.canUse(.healthWeightImport)) }
                    }
                }
            if entitlements.canUse(.healthWeightImport) {
                Toggle("Read weight from Health", isOn: $readWeight)
                    .onChange(of: readWeight) { _, enabled in
                        NotificationCenter.default.post(name: .healthSettingsDidChange, object: nil)
                        if enabled {
                            Task { try? await health.requestAuthorization(readWeight: true) }
                        }
                    }
            } else {
                Button {
                    paywallContext = .healthWeightImport
                } label: {
                    Label("Read weight from Health", systemImage: "lock.fill")
                }
            }
            Text(health.statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Sync last 30 days") {
                Task { await health.backfill(days: 30, container: modelContext.container) }
            }
            .disabled(!writeNutrition)
        }
        .sheet(item: $paywallContext) { context in
            ProPaywallSheet(context: context).presentationDetents([.medium, .large])
        }
    }
}

extension Notification.Name {
    static let healthSettingsDidChange = Notification.Name("healthSettingsDidChange")
}
