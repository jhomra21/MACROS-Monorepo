import Foundation
import OSLog
import SwiftData

enum PersistenceReporter {
    private static let logger = Logger(subsystem: "juan-test.cal-macro-tracker", category: "Persistence")

    static func persist<Result>(
        modelContext: ModelContext,
        operation: String,
        changes: () throws -> Result
    ) throws -> Result {
        do {
            let result = try changes()

            if modelContext.hasChanges {
                try modelContext.save()
            }

            logger.info("\(operation, privacy: .public) succeeded")
            return result
        } catch {
            if modelContext.hasChanges {
                modelContext.rollback()
            }

            logger.error("\(operation, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    static func persist<Result>(
        in container: ModelContainer,
        operation: String,
        changes: (ModelContext) throws -> Result
    ) throws -> Result {
        let isolatedContext = ModelContext(container)
        return try persist(modelContext: isolatedContext, operation: operation) {
            try changes(isolatedContext)
        }
    }
}
