import SwiftData
import SwiftUI

private enum AppRootSheetDestination: Identifiable, Hashable {
    case addFood(AddFoodEntryPoint, CalendarDay?)
    case foodCamera(CalendarDay?)
    case editLogEntry(PersistentIdentifier)

    var isCameraPresentation: Bool {
        switch self {
        case .foodCamera:
            true
        case let .addFood(entryPoint, _):
            entryPoint == .scanBarcode || entryPoint == .scanLabel
        case .editLogEntry:
            false
        }
    }

    var id: String {
        switch self {
        case let .addFood(entryPoint, loggingDay):
            "add-food:\(entryPoint.rawValue):\(String(describing: loggingDay))"
        case let .foodCamera(loggingDay):
            "food-camera:\(String(describing: loggingDay))"
        case let .editLogEntry(entryID):
            "edit-log-entry:\(String(describing: entryID))"
        }
    }
}

struct AppRootView: View {
    private enum Route: Hashable {
        case history
        case insights
        case settings
        case sharingDashboard
        case sharing(inviteInput: String?, requestId: Int)
    }

    @Binding private var pendingOpenRequest: AppOpenRequest?

    @AppStorage(AppStorageKeys.hasCompletedDashboardTutorial) private var hasCompletedDashboardTutorial = false
    @Namespace private var cameraTransition
    @State private var tutorial = DashboardTutorial()
    @State private var path: [Route] = []
    @State private var sheetDestination: AppRootSheetDestination?
    @State private var openRequestToken = 0

    init(pendingOpenRequest: Binding<AppOpenRequest?> = .constant(nil)) {
        _pendingOpenRequest = pendingOpenRequest
    }

    var body: some View {
        NavigationStack(path: $path) {
            DashboardScreen(
                cameraTransitionNamespace: cameraTransition,
                onOpenAddFood: { loggingDay in
                    presentSheet(.addFood(.addFood, loggingDay))
                },
                onOpenFoodCamera: { loggingDay in
                    presentSheet(.foodCamera(loggingDay))
                },
                onEditEntry: { entry in
                    presentSheet(.editLogEntry(entry.persistentModelID))
                },
                onOpenHistory: { open(.history) },
                onOpenInsights: { open(.insights) },
                onOpenSettings: { open(.settings) },
                onOpenSharing: { open(.sharingDashboard) }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .history:
                    HistoryScreen()
                case .insights:
                    InsightsScreen()
                case .settings:
                    SettingsScreen()
                case .sharingDashboard:
                    SharingDashboardScreen {
                        open(.sharing(inviteInput: nil, requestId: 0))
                    }
                    .overlay(alignment: .bottom) {
                        if tutorial.step == .returnFromSharing {
                            TutorialCaptionCard(step: .returnFromSharing)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)
                        }
                    }
                case let .sharing(inviteInput, _):
                    SharingScreen(initialInviteInput: inviteInput)
                }
            }
        }
        .environment(tutorial)
        .onChange(of: path) { _, newPath in
            if newPath.last == .sharingDashboard { tutorial.didOpenSharing() }
            if newPath.isEmpty { tutorial.didReturnToRoot() }
        }
        .onChange(of: canStartTutorial, initial: true) { _, canStart in
            if canStart { tutorial.start() }
        }
        .onChange(of: tutorial.step) { oldStep, newStep in
            if oldStep != nil, newStep == nil { hasCompletedDashboardTutorial = true }
        }
        .onChange(of: hasCompletedDashboardTutorial) { _, hasCompleted in
            if !hasCompleted { path.removeAll() }
        }
        .sheet(item: nonCameraSheetDestination) { destination in
            sheetPresentation(for: destination)
        }
        .fullScreenCover(item: cameraSheetDestination) { destination in
            sheetPresentation(for: destination)
        }
        .onChange(of: pendingOpenRequest) { _, newValue in
            applyPendingOpenRequest(newValue)
        }
        .task {
            applyPendingOpenRequest(pendingOpenRequest)
            await AppWarmupCoordinator.warmUpAfterFirstRender()
        }
        .modifier(ReviewPromptModifier())
    }

    @ViewBuilder
    private func sheetPresentation(for destination: AppRootSheetDestination) -> some View {
        switch destination {
        case .foodCamera:
            AppRootSheetContent(destination: destination)
                .navigationTransition(.zoom(sourceID: FoodCameraSheet.zoomTransitionID, in: cameraTransition))
                .presentationBackground(.clear)
        case let .addFood(entryPoint, _) where entryPoint == .scanBarcode || entryPoint == .scanLabel:
            AppRootSheetContent(destination: destination)
                .presentationBackground(.clear)
        default:
            NavigationStack {
                AppRootSheetContent(destination: destination)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var canStartTutorial: Bool {
        !hasCompletedDashboardTutorial && path.isEmpty && sheetDestination == nil && tutorial.isDashboardReady
    }

    private func open(_ route: Route) {
        path.append(route)
    }

    private func presentSheet(_ destination: AppRootSheetDestination) {
        sheetDestination = destination
    }

    private var nonCameraSheetDestination: Binding<AppRootSheetDestination?> {
        Binding(
            get: {
                guard sheetDestination?.isCameraPresentation == false else { return nil }
                return sheetDestination
            },
            set: { destination in
                if destination == nil, sheetDestination?.isCameraPresentation == true {
                    return
                }
                sheetDestination = destination
            }
        )
    }

    private var cameraSheetDestination: Binding<AppRootSheetDestination?> {
        Binding(
            get: {
                guard sheetDestination?.isCameraPresentation == true else { return nil }
                return sheetDestination
            },
            set: { destination in
                if destination == nil, sheetDestination?.isCameraPresentation == true {
                    sheetDestination = nil
                }
            }
        )
    }

    private func resetPresentedState() {
        path.removeAll()
        sheetDestination = nil
    }

    private func applyPendingOpenRequest(_ request: AppOpenRequest?) {
        guard let request else { return }

        switch request {
        case let .addFood(entryPoint):
            presentSheet(.addFood(entryPoint, nil))
        case let .sharing(inviteInput):
            resetPresentedState()
            openRequestToken += 1
            let requestId = openRequestToken
            DispatchQueue.main.async {
                path.append(.sharing(inviteInput: inviteInput, requestId: requestId))
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
                FoodCameraSheet(loggingDay: loggingDay, onFoodLogged: dismissSheet)
            case .scanLabel:
                FoodCameraSheet(loggingDay: loggingDay, onFoodLogged: dismissSheet)
            case .manualEntry:
                AddFoodScreen(initialMode: .manual, loggingDay: loggingDay)
            }
        case let .foodCamera(loggingDay):
            FoodCameraSheet(loggingDay: loggingDay, onFoodLogged: dismissSheet)
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
    @Environment(\.dismiss) private var dismiss

    let entryID: PersistentIdentifier

    var body: some View {
        if let entry = modelContext.model(for: entryID) as? LogEntry {
            if entry.isMealLog {
                LoggedMealDetailScreen(entry: entry)
            } else {
                EditLogEntryScreen(entry: entry)
            }
        } else {
            ContentUnavailableView(
                "Entry unavailable",
                systemImage: "fork.knife.circle",
                description: Text("This log entry is no longer available.")
            )
            .navigationTitle("Entry Unavailable")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
