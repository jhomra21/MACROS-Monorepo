import SwiftData
import SwiftUI

@MainActor
@Observable
final class AppLaunchState {
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
            phase = .ready(container)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
