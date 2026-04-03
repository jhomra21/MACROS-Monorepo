import Foundation
import SwiftData

@MainActor
enum AppModelContainerFactory {
    static func makePersistentContainer() throws -> ModelContainer {
        let container = try ModelContainer(for: DailyGoals.self, FoodItem.self, LogEntry.self)
        try AppBootstrap.bootstrap(modelContext: container.mainContext)
        return container
    }

    static func makePreviewContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: DailyGoals.self,
            FoodItem.self,
            LogEntry.self,
            configurations: configuration
        )
        try AppBootstrap.bootstrap(modelContext: container.mainContext)
        return container
    }

}
