import Foundation
import SwiftData

struct LogEntryDaySnapshot {
    let entries: [LogEntry]
    let totals: NutritionSnapshot
}

enum LogEntryDaySummary {
    static func descriptor(for date: Date) -> FetchDescriptor<LogEntry> {
        let interval = date.dayInterval
        let start = interval.start
        let end = interval.end
        let predicate = #Predicate<LogEntry> { entry in
            entry.dateLogged >= start && entry.dateLogged < end
        }

        return FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\LogEntry.dateLogged, order: .reverse)]
        )
    }

    static func snapshot(for entries: [LogEntry]) -> LogEntryDaySnapshot {
        LogEntryDaySnapshot(entries: entries, totals: NutritionMath.totals(for: entries))
    }
}
