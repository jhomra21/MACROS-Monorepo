import Foundation
import SwiftData

enum LogEntryQuery {
    static func descriptor(for day: CalendarDay, order: SortOrder = .reverse) -> FetchDescriptor<LogEntry> {
        descriptor(for: day.dayInterval, order: order)
    }

    static func descriptor(for interval: DayInterval, order: SortOrder = .reverse) -> FetchDescriptor<LogEntry> {
        descriptor(start: interval.start, end: interval.end, order: order)
    }

    static func descriptor(
        for days: [CalendarDay],
        fallbackDay: CalendarDay,
        order: SortOrder = .reverse
    ) -> FetchDescriptor<LogEntry> {
        let firstDay = days.first ?? fallbackDay
        let lastDay = days.last ?? fallbackDay
        return descriptor(start: firstDay.startDate, end: lastDay.dayInterval.end, order: order)
    }

    static func descriptor(start: Date, end: Date, order: SortOrder = .reverse) -> FetchDescriptor<LogEntry> {
        let predicate = #Predicate<LogEntry> { entry in
            entry.dateLogged >= start && entry.dateLogged < end
        }

        return FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\LogEntry.dateLogged, order: order)]
        )
    }
}
