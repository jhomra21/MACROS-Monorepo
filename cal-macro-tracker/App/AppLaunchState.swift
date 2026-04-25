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

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        do {
            let container = try AppModelContainerFactory.makePersistentContainer()
            try await AppBootstrap.bootstrapIfNeeded(in: container)
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
            phase = .failed(error.localizedDescription)
        }
    }
}
