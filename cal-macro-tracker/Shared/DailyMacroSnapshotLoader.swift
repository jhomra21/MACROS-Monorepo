import Foundation
import SwiftData

struct DailyMacroSnapshot: Hashable {
    let totals: NutritionSnapshot
    let goals: MacroGoalsSnapshot

    static let empty = DailyMacroSnapshot(totals: .zero, goals: .default)
}

struct DailyNutritionSnapshot: Hashable {
    let totals: NutritionSnapshot
    let entryCount: Int
}

enum DailyMacroSnapshotLoader {
    static func load(for date: Date = .now, in container: ModelContainer) throws -> DailyMacroSnapshot {
        let modelContext = ModelContext(container)
        let entries: [LogEntry] = try modelContext.fetch(LogEntryQuery.descriptor(for: CalendarDay(date: date)))
        let goals = DailyGoals.activeRecord(from: try modelContext.fetch(FetchDescriptor<DailyGoals>()))

        return DailyMacroSnapshot(
            totals: NutritionSnapshot.totals(for: entries),
            goals: MacroGoalsSnapshot(goals: goals)
        )
    }

    static func loadNutrition(for date: Date = .now, in container: ModelContainer) throws -> DailyNutritionSnapshot {
        let modelContext = ModelContext(container)
        let entries: [LogEntry] = try modelContext.fetch(LogEntryQuery.descriptor(for: CalendarDay(date: date)))
        return DailyNutritionSnapshot(totals: NutritionSnapshot.totals(for: entries), entryCount: entries.count)
    }
}
