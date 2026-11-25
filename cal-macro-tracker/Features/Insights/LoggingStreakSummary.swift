import Foundation

/// A log entry reduced to the two instants the streak rules read.
struct LoggingStreakEntry: Equatable {
    let dateLogged: Date
    let createdAt: Date
}

/// Logging streak, best streak and the last four weeks of day states.
///
/// Rules, all in the local calendar:
/// - 48-hour rule: a day counts only if it has an entry created no later than the end of the following day.
///   Late-logged food is still saved and still adds to `totalLoggedDays`; it just does not extend a streak.
///   `LogEntry.createdAt` is non-optional, set when the row is created, and kept by backup export and import,
///   so restored history keeps its original timing and nothing is guessed for older entries.
/// - Flex day: one per Monday-to-Sunday week. A marked day is used if the week has one; otherwise the first
///   settled day without a counted entry is used automatically. A flex day bridges the streak without adding
///   to it, unless the day was logged anyway, in which case it counts like any logged day.
/// - Today and yesterday are never missed: yesterday can still be logged until the end of today.
struct LoggingStreakSummary: Equatable {
    enum DayState: Equatable {
        case logged, flex, missed, future
    }

    struct Day: Equatable {
        let day: CalendarDay
        let state: DayState
    }

    let current: Int
    let best: Int
    let lastCountedDay: CalendarDay?
    /// Days with any entry up to today, whenever the entry was created.
    let totalLoggedDays: Int
    /// The current week first, then the three before it. Each runs Monday to Sunday.
    let weeks: [[Day]]

    var currentWeek: [Day] { weeks.first ?? [] }

    static func make(
        entries: [LoggingStreakEntry],
        today: CalendarDay,
        flexDays: Set<CalendarDay>
    ) -> LoggingStreakSummary {
        var timeline = Timeline(today: today)
        for entry in entries { timeline.add(entry) }
        for day in flexDays { timeline.mark(day) }
        return timeline.summary()
    }
}

/// Day-index arithmetic behind `LoggingStreakSummary`. Index 0 is today and negative indexes are the past,
/// so DST days and time zone changes never shift the week or streak math.
private struct Timeline {
    let today: CalendarDay
    private let calendar: Calendar
    private let origin: Date
    private let mondayOffsetOfToday: Int
    private var dayIndexes: [Date: Int] = [:]
    private var logged: Set<Int> = []
    private var counted: Set<Int> = []
    private var markedByWeek: [Int: Int] = [:]
    private var autoFlexByWeek: [Int: Int?] = [:]

    init(today: CalendarDay) {
        self.today = today
        calendar = today.resolvedCalendar
        origin = today.startDate
        mondayOffsetOfToday = (calendar.component(.weekday, from: origin) + 5) % 7
    }

    mutating func add(_ entry: LoggingStreakEntry) {
        let index = index(ofDayStart: calendar.startOfDay(for: entry.dateLogged))
        guard index <= 0 else { return }
        logged.insert(index)
        guard !counted.contains(index), entry.createdAt <= deadline(forDayIndex: index) else { return }
        counted.insert(index)
    }

    mutating func mark(_ day: CalendarDay) {
        let index = index(ofDayStart: day.startDate)
        let week = weekStart(of: index)
        markedByWeek[week] = min(markedByWeek[week] ?? index, index)
    }

    mutating func summary() -> LoggingStreakSummary {
        let first = counted.min()
        var current = 0
        var best = 0
        if let first {
            for index in first...0 {
                switch state(of: index, first: first) {
                case .logged: current += 1
                case .flex: if counted.contains(index) { current += 1 }
                case .missed: current = 0
                case .future: break
                }
                best = max(best, current)
            }
        }

        let currentWeekStart = weekStart(of: 0)
        var weeks: [[LoggingStreakSummary.Day]] = []
        for weekOffset in 0..<4 {
            let start = currentWeekStart - 7 * weekOffset
            var days: [LoggingStreakSummary.Day] = []
            for index in start..<start + 7 {
                guard let day = today.advanced(byDays: index) else { continue }
                days.append(LoggingStreakSummary.Day(day: day, state: state(of: index, first: first)))
            }
            weeks.append(days)
        }
        return LoggingStreakSummary(
            current: current,
            best: best,
            lastCountedDay: counted.max().flatMap { today.advanced(byDays: $0) },
            totalLoggedDays: logged.count,
            weeks: weeks
        )
    }

    private mutating func state(of index: Int, first: Int?) -> LoggingStreakSummary.DayState {
        if flexDay(inWeekStartingAt: weekStart(of: index), first: first) == index { return .flex }
        if index > 0 { return .future }
        if counted.contains(index) { return .logged }
        // Before the first counted day there is no streak to miss; today and yesterday can still be logged.
        guard let first, index >= first, index < -1 else { return .future }
        return .missed
    }

    private mutating func flexDay(inWeekStartingAt start: Int, first: Int?) -> Int? {
        if let marked = markedByWeek[start] { return marked }
        if let cached = autoFlexByWeek[start] { return cached }
        // Only settled days are eligible: index -1 (yesterday) and 0 (today) can still be logged.
        let lowest = max(start, first ?? 0)
        let highest = min(start + 6, -2)
        let automatic = lowest <= highest ? (lowest...highest).first { !counted.contains($0) } : nil
        autoFlexByWeek[start] = .some(automatic)
        return automatic
    }

    private func weekStart(of index: Int) -> Int {
        let sinceMonday = ((mondayOffsetOfToday + index) % 7 + 7) % 7
        return index - sinceMonday
    }

    private mutating func index(ofDayStart start: Date) -> Int {
        if let cached = dayIndexes[start] { return cached }
        let index = calendar.dateComponents([.day], from: origin, to: start).day ?? 0
        dayIndexes[start] = index
        return index
    }

    /// The end of the day after `index`, which is the start of the day after that.
    private func deadline(forDayIndex index: Int) -> Date {
        let target = calendar.date(byAdding: .day, value: index + 2, to: origin) ?? origin
        return calendar.startOfDay(for: target)
    }
}

enum StreakBadge: Int, CaseIterable, Identifiable {
    case oneWeek = 7
    case oneMonth = 30
    case threeMonths = 90
    case sixMonths = 180
    case oneYear = 365

    var id: Int { rawValue }
    var days: Int { rawValue }

    var title: String {
        switch self {
        case .oneWeek: "One Week"
        case .oneMonth: "One Month"
        case .threeMonths: "Three Months"
        case .sixMonths: "Six Months"
        case .oneYear: "One Year"
        }
    }

    /// Concentric rings drawn on the medallion.
    var ringCount: Int {
        switch self {
        case .oneWeek: 1
        case .oneMonth: 2
        case .threeMonths, .sixMonths, .oneYear: 3
        }
    }

    /// Badges are permanent: `highestEarnedDays` is the persisted threshold, so a lower recomputed best never removes one.
    static func earned(best: Int, highestEarnedDays: Int) -> [StreakBadge] {
        let reached = max(best, highestEarnedDays)
        return allCases.filter { $0.days <= reached }
    }
}

/// Flex day marks as comma-separated `yyyy-MM-dd` keys, so they live in UserDefaults and backups without a schema change.
enum FlexDayMarks {
    static func days(from stored: String, calendar: Calendar) -> Set<CalendarDay> {
        Set(
            stored.split(separator: ",").compactMap { key in
                let parts = key.split(separator: "-").compactMap { Int($0) }
                guard parts.count == 3,
                    let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
                else { return nil }
                return CalendarDay(date: date, calendar: calendar)
            }
        )
    }

    /// Replaces any mark inside `week` with `day`, or clears the week when `day` is nil.
    static func setting(_ day: CalendarDay?, inWeek week: [CalendarDay], stored: String) -> String {
        let weekKeys = Set(week.map(\.sharingDayKey))
        let kept = stored.split(separator: ",").map(String.init).filter { !weekKeys.contains($0) }
        return (kept + (day.map { [$0.sharingDayKey] } ?? [])).sorted().joined(separator: ",")
    }
}
