import SwiftData
import SwiftUI

/// Reads every log entry's two dates once, builds the streak summary and records earned badges.
///
/// The summary is memoized on a cheap fingerprint of the inputs, so parent re-renders (scrolling Today, for
/// example) do not repeat the calendar work. Only `dateLogged` and `createdAt` are fetched.
struct LoggingStreakReader<Content: View>: View {
    @Query private var entries: [LogEntry]
    @AppStorage(AppStorageKeys.streakFlexDays) private var flexDays = ""
    @AppStorage(AppStorageKeys.streakHighestBadgeDays) private var highestBadgeDays = 0
    @State private var cache = Cache()

    let today: CalendarDay
    @ViewBuilder let content: (LoggingStreakSummary, [StreakBadge]) -> Content

    init(
        today: CalendarDay,
        @ViewBuilder content: @escaping (LoggingStreakSummary, [StreakBadge]) -> Content
    ) {
        self.today = today
        self.content = content
        var descriptor = LogEntryQuery.descriptor(start: .distantPast, end: today.dayInterval.end, order: .forward)
        descriptor.propertiesToFetch = [\LogEntry.dateLogged, \LogEntry.createdAt]
        _entries = Query(descriptor)
    }

    var body: some View {
        let summary = summary
        content(summary, StreakBadge.earned(best: summary.best, highestEarnedDays: highestBadgeDays))
            .onChange(of: summary.best, initial: true) { _, best in
                let earnedDays = StreakBadge.earned(best: best, highestEarnedDays: highestBadgeDays).last?.days ?? 0
                if earnedDays > highestBadgeDays { highestBadgeDays = earnedDays }
            }
    }

    private var summary: LoggingStreakSummary {
        let key = Fingerprint(
            today: today,
            flexDays: flexDays,
            count: entries.count,
            checksum: entries.reduce(0) { sum, entry in
                sum &+ entry.dateLogged.timeIntervalSinceReferenceDate.bitPattern &* 31
                    &+ entry.createdAt.timeIntervalSinceReferenceDate.bitPattern
            }
        )
        if let summary = cache.summary, cache.key == key { return summary }
        let summary = LoggingStreakSummary.make(
            entries: entries.map { LoggingStreakEntry(dateLogged: $0.dateLogged, createdAt: $0.createdAt) },
            today: today,
            flexDays: FlexDayMarks.days(from: flexDays, calendar: today.resolvedCalendar)
        )
        cache.key = key
        cache.summary = summary
        return summary
    }

    private struct Fingerprint: Equatable {
        let today: CalendarDay
        let flexDays: String
        let count: Int
        let checksum: UInt64
    }

    /// Memoization only. It is written while the body runs and is never read by SwiftUI, so it needs no observation.
    private final class Cache {
        var key: Fingerprint?
        var summary: LoggingStreakSummary?
    }
}
