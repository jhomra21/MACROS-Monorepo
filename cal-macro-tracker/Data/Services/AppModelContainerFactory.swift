import Foundation
import SwiftData

enum AppModelContainerFactory {
    static func makePersistentContainer() throws -> ModelContainer {
        try SharedModelContainerFactory.makePersistentContainer()
    }

    // periphery:ignore - preview-only container used by SwiftUI previews
    static func makePreviewContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: DailyGoals.self,
            FoodItem.self,
            LogEntry.self,
            configurations: configuration
        )
        try AppBootstrap.bootstrapPreview(modelContext: container.mainContext)
        return container
    }
}
