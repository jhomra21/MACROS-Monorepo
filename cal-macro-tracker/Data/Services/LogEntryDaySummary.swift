import Foundation
import SwiftData

struct LogEntryDaySnapshot {
    let entries: [LogEntry]
    let totals: NutritionSnapshot
    let secondaryTotals: SecondaryNutritionSnapshot

    static let empty = LogEntryDaySnapshot(entries: [], totals: .zero, secondaryTotals: .zero)
}

enum LogEntryDaySummary {
    static func snapshot(for entries: [LogEntry]) -> LogEntryDaySnapshot {
        LogEntryDaySnapshot(
            entries: entries,
            totals: NutritionSnapshot.totals(for: entries),
            secondaryTotals: SecondaryNutritionSnapshot.totals(for: entries)
        )
    }

    static func snapshotsByDay(for entries: [LogEntry], matching days: [CalendarDay]) -> [CalendarDay: LogEntryDaySnapshot] {
        guard let calendar = days.first?.resolvedCalendar else { return [:] }
        let entriesByDay = Dictionary(grouping: entries) { entry in
            CalendarDay(date: entry.dateLogged, calendar: calendar)
        }

        return days.reduce(into: [CalendarDay: LogEntryDaySnapshot]()) { snapshots, day in
            snapshots[day] = snapshot(for: entriesByDay[day] ?? [])
        }
    }
}
