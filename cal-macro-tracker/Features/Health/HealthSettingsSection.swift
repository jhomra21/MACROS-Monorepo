import SwiftData
import SwiftUI

struct HealthSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppEntitlements.self) private var entitlements
    @Environment(HealthKitService.self) private var health
    @AppStorage(AppStorageKeys.healthNutritionWriteEnabled) private var writeNutrition = false
    @AppStorage(AppStorageKeys.healthWeightReadEnabled) private var readWeight = false
    @State private var authorizationErrorMessage: String?

    var body: some View {
        Section {
            Toggle("Write nutrition to Health", isOn: $writeNutrition)
                .onChange(of: writeNutrition) { _, enabled in
                    NotificationCenter.default.post(name: .healthSettingsDidChange, object: nil)
                    if !enabled {
                        Task { await health.cancelBackfill() }
                    }
                    if enabled {
                        Task {
                            await requestAuthorization(readWeight: readWeight && entitlements.canUse(.healthWeightImport))
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
                                await requestAuthorization(readWeight: true)
                                health.restartWeightObservation(container: modelContext.container)
                                NotificationCenter.default.post(name: .healthSettingsDidChange, object: nil)
                            }
                        }
                    }
            } else {
                ProLockedRow(title: "Read weight from Health", context: .healthWeightImport)
            }
            Button {
                health.startBackfill(days: 30, container: modelContext.container)
            } label: {
                if health.isBackfilling {
                    Label {
                        Text("Syncing Last 30 Days")
                    } icon: {
                        ProgressView()
                    }
                } else {
                    Text("Sync Last 30 Days")
                }
            }
            .disabled(!writeNutrition || health.isBackfilling)
        } header: {
            Text("Apple Health")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(health.statusText)
                Text("MACROS reads and writes only what you allow in the Health app.")
            }
        }
        .onDisappear {
            Task { await health.cancelBackfill() }
        }
        .errorBanner(
            message: Binding(
                get: { authorizationErrorMessage ?? health.backfillErrorMessage },
                set: { message in
                    if message == nil {
                        authorizationErrorMessage = nil
                        health.clearBackfillError()
                    }
                }
            ),
            title: "Apple Health Error"
        )
    }

    private func requestAuthorization(readWeight: Bool) async {
        do {
            try await health.requestAuthorization(readWeight: readWeight)
        } catch {
            authorizationErrorMessage = error.localizedDescription
        }
    }
}

extension Notification.Name {
    static let healthSettingsDidChange = Notification.Name("healthSettingsDidChange")
}
