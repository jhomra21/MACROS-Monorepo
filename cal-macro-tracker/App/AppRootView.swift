import SwiftData
import SwiftUI

private enum AppRootSheetDestination: Identifiable, Hashable {
    case addFood(AddFoodEntryPoint, CalendarDay?)
    case editLogEntry(PersistentIdentifier)

    var id: String {
        switch self {
        case let .addFood(entryPoint, loggingDay):
            "add-food:\(entryPoint.rawValue):\(String(describing: loggingDay))"
        case let .editLogEntry(entryID):
            "edit-log-entry:\(String(describing: entryID))"
        }
    }
}

struct AppRootView: View {
    private enum Route: Hashable {
        case history
        case settings
        case sharing(inviteInput: String?, requestId: Int)
    }

    @Binding private var pendingOpenRequest: AppOpenRequest?

    @State private var destination: Route?
    @State private var sheetDestination: AppRootSheetDestination?
    @State private var dashboardResetToken = 0
    @State private var openRequestToken = 0

    init(pendingOpenRequest: Binding<AppOpenRequest?> = .constant(nil)) {
        _pendingOpenRequest = pendingOpenRequest
    }

    var body: some View {
        NavigationStack {
            DashboardScreen(
                resetToTodayToken: dashboardResetToken,
                onOpenAddFood: { loggingDay in
                    presentSheet(.addFood(.addFood, loggingDay))
                },
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
                case let .sharing(inviteInput, _):
                    SharingScreen(initialInviteInput: inviteInput)
                }
            }
        }
        .sheet(item: $sheetDestination) { destination in
            NavigationStack {
                AppRootSheetContent(destination: destination)
            }
        }
        .onChange(of: pendingOpenRequest) { _, newValue in
            applyPendingOpenRequest(newValue)
        }
        .task {
            applyPendingOpenRequest(pendingOpenRequest)
            await AppWarmupCoordinator.warmUpAfterFirstRender()
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
            dashboardResetToken += 1
        case let .addFood(entryPoint):
            presentSheet(.addFood(entryPoint, nil))
        case let .sharing(inviteInput):
            resetPresentedState()
            openRequestToken += 1
            let requestId = openRequestToken
            DispatchQueue.main.async {
                destination = .sharing(inviteInput: inviteInput, requestId: requestId)
            }
        }

        pendingOpenRequest = nil
    }
}

private struct AppRootSheetContent: View {
    @Environment(\.dismiss) private var dismiss

    let destination: AppRootSheetDestination

    var body: some View {
        switch destination {
        case let .addFood(entryPoint, loggingDay):
            switch entryPoint {
            case .addFood:
                AddFoodScreen(loggingDay: loggingDay)
            case .scanBarcode:
                BarcodeScanScreen(onFoodLogged: dismissSheet, loggingDay: loggingDay, entryMode: .immediateCamera)
                    .toolbar {
                        ToolbarItem(placement: .appTopBarTrailing) {
                            Button("Done") {
                                dismissSheet()
                            }
                        }
                    }
            case .scanLabel:
                LabelScanScreen(onFoodLogged: dismissSheet, loggingDay: loggingDay)
                    .toolbar {
                        ToolbarItem(placement: .appTopBarTrailing) {
                            Button("Done") {
                                dismissSheet()
                            }
                        }
                    }
            case .manualEntry:
                AddFoodScreen(initialMode: .manual, loggingDay: loggingDay)
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
