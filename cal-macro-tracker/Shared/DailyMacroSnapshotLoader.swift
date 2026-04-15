import Foundation
import SwiftData

struct DailyMacroSnapshot: Hashable {
    let totals: NutritionSnapshot
    let goals: MacroGoalsSnapshot

    static let empty = DailyMacroSnapshot(totals: .zero, goals: .default)
}

enum DailyMacroSnapshotLoader {
    static func load(for date: Date = .now, in container: ModelContainer) throws -> DailyMacroSnapshot {
        let modelContext = ModelContext(container)
        let entries: [LogEntry] = try modelContext.fetch(LogEntryQuery.descriptor(for: CalendarDay(date: date)))
        let goals = try modelContext.fetch(FetchDescriptor<DailyGoals>()).first

        return DailyMacroSnapshot(
            totals: NutritionSnapshot.totals(for: entries),
            goals: MacroGoalsSnapshot(goals: goals)
        )
    }
}
