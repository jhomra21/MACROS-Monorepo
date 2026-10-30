#if DEBUG
import SwiftData
import SwiftUI

struct DeveloperSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PurchaseStore.self) private var store
    @State private var isConfirmingDemoData = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            Button(store.hasPro ? "Revoke Debug Pro" : "Grant Debug Pro") {
                store.setDebugPro(!store.hasPro)
            }
            Button("Load Demo Data") { isConfirmingDemoData = true }
                .confirmationDialog("Load demo data?", isPresented: $isConfirmingDemoData, titleVisibility: .visible) {
                    Button("Replace Data", role: .destructive) { loadDemoData() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This replaces all data on this device.")
                }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        } header: {
            Text("Developer")
        }
    }

    private func loadDemoData() {
        let container = modelContext.container
        Task {
            do {
                try await DemoDataSeeder.seed(into: container)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
#endif
