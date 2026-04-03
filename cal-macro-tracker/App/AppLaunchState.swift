import SwiftData
import SwiftUI

@MainActor
@Observable
final class AppLaunchState {
    private(set) var modelContainer: ModelContainer?
    private(set) var launchErrorMessage: String?

    init() {
        do {
            modelContainer = try AppModelContainerFactory.makePersistentContainer()
        } catch {
            launchErrorMessage = error.localizedDescription
        }
    }
}
