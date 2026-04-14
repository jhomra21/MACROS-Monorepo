import SwiftData
import SwiftUI

private enum AppRootSheetDestination: Identifiable, Hashable {
    case addFood(AddFoodEntryPoint)
    case editLogEntry(PersistentIdentifier)

    var id: String {
        switch self {
        case let .addFood(entryPoint):
            "add-food:\(entryPoint.rawValue)"
        case let .editLogEntry(entryID):
            "edit-log-entry:\(String(describing: entryID))"
        }
    }
}

struct AppRootView: View {
    private enum Route: Hashable {
        case history
        case settings
    }

    @Binding private var pendingOpenRequest: AppOpenRequest?

    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @State private var destination: Route?
    @State private var sheetDestination: AppRootSheetDestination?

    init(pendingOpenRequest: Binding<AppOpenRequest?> = .constant(nil)) {
        _pendingOpenRequest = pendingOpenRequest
    }

    var body: some View {
        NavigationStack {
            DashboardScreen(
                onOpenAddFood: { presentSheet(.addFood(.addFood)) },
                onEditEntry: { entry in
                    presentSheet(.editLogEntry(entry.persistentModelID))
                },
                onOpenHistory: { open(.history) },
                onOpenSettings: { open(.settings) }
            )
            .navigationDestination(item: $destination) { route in
                switch route {
                case .history:
                    HistoryScreen()
                case .settings:
                    SettingsScreen()
                }
            }
        }
        .sheet(item: $sheetDestination) { destination in
            NavigationStack {
                AppRootSheetContent(destination: destination, foods: foods)
            }
        }
        .onChange(of: pendingOpenRequest) { _, newValue in
            applyPendingOpenRequest(newValue)
        }
        .task {
            applyPendingOpenRequest(pendingOpenRequest)
        }
    }

    private func open(_ route: Route) {
        guard destination == nil else { return }
        destination = route
    }

    private func presentSheet(_ destination: AppRootSheetDestination) {
        sheetDestination = destination
    }

    private func resetPresentedState() {
        destination = nil
        sheetDestination = nil
    }

    private func applyPendingOpenRequest(_ request: AppOpenRequest?) {
        guard let request else { return }

        switch request {
        case .dashboard:
            resetPresentedState()
        case let .addFood(entryPoint):
            presentSheet(.addFood(entryPoint))
        }

        pendingOpenRequest = nil
    }
}

private struct AppRootSheetContent: View {
    @Environment(\.dismiss) private var dismiss

    let destination: AppRootSheetDestination
    let foods: [FoodItem]

    var body: some View {
        switch destination {
        case let .addFood(entryPoint):
            switch entryPoint {
            case .addFood:
                AddFoodScreen(foods: foods)
            case .scanBarcode:
                BarcodeScanScreen(onFoodLogged: dismissSheet, entryMode: .immediateCamera)
                    .toolbar {
                        ToolbarItem(placement: .appTopBarTrailing) {
                            Button("Done") {
                                dismissSheet()
                            }
                        }
                    }
            case .scanLabel:
                LabelScanScreen(onFoodLogged: dismissSheet)
                    .toolbar {
                        ToolbarItem(placement: .appTopBarTrailing) {
                            Button("Done") {
                                dismissSheet()
                            }
                        }
                    }
            case .manualEntry:
                AddFoodScreen(foods: foods, initialMode: .manual)
            }
        case let .editLogEntry(entryID):
            EditLogEntrySheetContent(entryID: entryID)
        }
    }

    private func dismissSheet() {
        dismiss()
    }
}

private struct EditLogEntrySheetContent: View {
    @Environment(\.modelContext) private var modelContext

    let entryID: PersistentIdentifier

    var body: some View {
        if let entry = modelContext.model(for: entryID) as? LogEntry {
            EditLogEntryScreen(entry: entry)
        } else {
            ContentUnavailableView(
                "Entry unavailable",
                systemImage: "fork.knife.circle",
                description: Text("This log entry is no longer available.")
            )
        }
    }
}
