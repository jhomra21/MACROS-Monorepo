import OSLog
import SwiftData
import SwiftUI

@MainActor
@Observable
final class AppLaunchState {
    private static let logger = Logger(subsystem: "juan-test.cal-macro-tracker", category: "AppLaunch")

    enum Phase {
        case launching
        case ready(ModelContainer)
        case failed(String)
    }

    private(set) var phase: Phase = .launching
    private var hasStarted = false

    private static func makeContainer() async throws -> ModelContainer {
        #if DEBUG
        if UITestFixture.current != nil {
            let container = try AppModelContainerFactory.makePreviewContainer()
            try await DemoDataSeeder.seed(into: container)
            return container
        }
        #endif
        let container = try AppModelContainerFactory.makePersistentContainer()
        try await AppBootstrap.bootstrapIfNeeded(in: container)
        return container
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        do {
            let container = try await Self.makeContainer()
            let profile = try BodyProfileRepository.activeProfile(modelContext: container.mainContext)
            WeightUnit.initializeIfNeeded(profileUnitSystem: profile?.unitSystem)
            WidgetTimelineReloader.reloadMacroWidgets()
            phase = .ready(container)
            Task { @MainActor in
                do {
                    try await AppBootstrap.repairSecondaryNutrientsIfNeeded(in: container)
                    WidgetTimelineReloader.reloadMacroWidgets()
                } catch {
                    Self.logger.error("Secondary nutrient repair failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        } catch {
            let launchError = error as NSError
            Self.logger.error("App launch failed: domain=\(launchError.domain, privacy: .public), code=\(launchError.code)")
            phase = .failed(error.localizedDescription)
        }
    }
}
