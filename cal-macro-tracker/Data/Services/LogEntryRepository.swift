import Foundation
import SwiftData

@MainActor
struct LogEntryRepository {
    let modelContext: ModelContext
    let onDailyTotalsChanged: ((ModelContainer) -> Void)?

    init(modelContext: ModelContext, onDailyTotalsChanged: ((ModelContainer) -> Void)? = nil) {
        self.modelContext = modelContext
        self.onDailyTotalsChanged = onDailyTotalsChanged
    }
}
