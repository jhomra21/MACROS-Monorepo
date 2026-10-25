import SwiftData
import SwiftUI

struct LoggingStreakLine: View {
    @Query private var entries: [LogEntry]

    let today: CalendarDay
    let onOpenInsights: () -> Void

    init(today: CalendarDay, onOpenInsights: @escaping () -> Void) {
        self.today = today
        self.onOpenInsights = onOpenInsights
        _entries = Query(LogEntryQuery.descriptor(start: .distantPast, end: today.dayInterval.end))
    }

    private var streak: Int {
        let calendar = today.resolvedCalendar
        let loggedDays = Set(entries.map { CalendarDay(date: $0.dateLogged, calendar: calendar) })
        return InsightsAnalytics.currentStreak(days: Array(loggedDays), today: today)
    }

    var body: some View {
        if streak > 1 {
            Button(action: onOpenInsights) {
                Text("\(streak)-day logging streak")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(streak)-day logging streak. Open Insights.")
        }
    }
}
