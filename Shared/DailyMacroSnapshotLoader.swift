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
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let descriptor = FetchDescriptor<LogEntry>(
            predicate: #Predicate { entry in
                entry.dateLogged >= start && entry.dateLogged < end
            }
        )
        let entries: [LogEntry] = try modelContext.fetch(descriptor)
        let goals = try modelContext.fetch(FetchDescriptor<DailyGoals>()).first

        return DailyMacroSnapshot(
            totals: NutritionSnapshot.totals(for: entries),
            goals: MacroGoalsSnapshot(goals: goals)
        )
    }
}
