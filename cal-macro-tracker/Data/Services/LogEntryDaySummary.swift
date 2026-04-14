import Foundation
import SwiftData

struct LogEntryDaySnapshot {
    let entries: [LogEntry]
    let totals: NutritionSnapshot

    static let empty = LogEntryDaySnapshot(entries: [], totals: .zero)
}

enum LogEntryDaySummary {
    static func descriptor(for day: CalendarDay) -> FetchDescriptor<LogEntry> {
        descriptor(start: day.dayInterval.start, end: day.dayInterval.end)
    }

    static func descriptor(start: Date, end: Date) -> FetchDescriptor<LogEntry> {
        let predicate = #Predicate<LogEntry> { entry in
            entry.dateLogged >= start && entry.dateLogged < end
        }

        return FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\LogEntry.dateLogged, order: .reverse)]
        )
    }

    static func snapshot(for entries: [LogEntry]) -> LogEntryDaySnapshot {
        LogEntryDaySnapshot(entries: entries, totals: NutritionSnapshot.totals(for: entries))
    }

    static func snapshotsByDay(for entries: [LogEntry], matching days: [CalendarDay]) -> [CalendarDay: LogEntryDaySnapshot] {
        let entriesByDay = Dictionary(grouping: entries) { entry in
            entry.dateLogged.calendarDay
        }

        return days.reduce(into: [CalendarDay: LogEntryDaySnapshot]()) { snapshots, day in
            snapshots[day] = snapshot(for: entriesByDay[day] ?? [])
        }
    }
}
