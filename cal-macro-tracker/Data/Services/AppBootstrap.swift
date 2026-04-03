import Foundation
import SwiftData

@MainActor
enum AppBootstrap {
    static func bootstrap(modelContext: ModelContext) throws {
        try CommonFoodSeedLoader.seedIfNeeded(modelContext: modelContext)
        try seedGoalsIfNeeded(modelContext: modelContext)
    }

    private static func seedGoalsIfNeeded(modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<DailyGoals>()
        let count = try modelContext.fetchCount(descriptor)
        guard count == 0 else { return }

        try PersistenceReporter.persist(modelContext: modelContext, operation: "Seed daily goals") {
            modelContext.insert(DailyGoals())
        }
    }
}
