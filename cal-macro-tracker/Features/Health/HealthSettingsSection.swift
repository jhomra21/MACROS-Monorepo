import SwiftData
import SwiftUI

struct HealthSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppEntitlements.self) private var entitlements
    @Environment(HealthKitService.self) private var health
    @AppStorage(AppStorageKeys.healthNutritionWriteEnabled) private var writeNutrition = false
    @AppStorage(AppStorageKeys.healthWeightReadEnabled) private var readWeight = false

    var body: some View {
        Section("Apple Health") {
            Toggle("Write nutrition to Health", isOn: $writeNutrition)
                .onChange(of: writeNutrition) { _, enabled in
                    NotificationCenter.default.post(name: .healthSettingsDidChange, object: nil)
                    if !enabled {
                        Task { await health.cancelBackfill() }
                    }
                    if enabled {
                        Task {
                            try? await health.requestAuthorization(readWeight: readWeight && entitlements.canUse(.healthWeightImport))
                            if readWeight && entitlements.canUse(.healthWeightImport) {
                                health.restartWeightObservation(container: modelContext.container)
                            }
                            NotificationCenter.default.post(name: .healthSettingsDidChange, object: nil)
                        }
                    }
                }
            if entitlements.canUse(.healthWeightImport) {
                Toggle("Read weight from Health", isOn: $readWeight)
                    .onChange(of: readWeight) { _, enabled in
                        NotificationCenter.default.post(name: .healthSettingsDidChange, object: nil)
                        if enabled {
                            Task {
                                try? await health.requestAuthorization(readWeight: true)
                                health.restartWeightObservation(container: modelContext.container)
                                NotificationCenter.default.post(name: .healthSettingsDidChange, object: nil)
                            }
                        }
                    }
            } else {
                ProLockedRow(title: "Read weight from Health", context: .healthWeightImport)
            }
            Text(health.statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                health.startBackfill(days: 30, container: modelContext.container)
            } label: {
                if health.isBackfilling {
                    Label("Syncing last 30 days", systemImage: "arrow.triangle.2.circlepath")
                } else {
                    Text("Sync last 30 days")
                }
            }
            .disabled(!writeNutrition || health.isBackfilling)
        }
        .onDisappear {
            Task { await health.cancelBackfill() }
        }
        .errorBanner(
            message: Binding(
                get: { health.backfillErrorMessage },
                set: { message in
                    if message == nil { health.clearBackfillError() }
                }
            )
        )
    }
}

extension Notification.Name {
    static let healthSettingsDidChange = Notification.Name("healthSettingsDidChange")
}
