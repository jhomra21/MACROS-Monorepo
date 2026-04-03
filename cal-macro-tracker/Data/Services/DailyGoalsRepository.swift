import Foundation
import SwiftData

@MainActor
struct DailyGoalsRepository {
    let modelContext: ModelContext

    func saveGoals(from draft: DailyGoalsDraft, to goals: DailyGoals, operation: String) throws {
        if let validationError = draft.validationError {
            throw validationError
        }

        let goalsID = goals.persistentModelID

        try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            guard let isolatedGoals = isolatedContext.model(for: goalsID) as? DailyGoals else {
                throw NSError(domain: "DailyGoalsRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load daily goals for saving."])
            }

            draft.apply(to: isolatedGoals)
        }
    }
}
