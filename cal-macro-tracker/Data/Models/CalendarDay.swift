import Foundation

struct DayInterval: Hashable {
    let start: Date
    let end: Date
}

struct CalendarDay: Hashable, Sendable {
    let calendarIdentifier: Calendar.Identifier
    let era: Int?
    let year: Int
    let month: Int
    let day: Int

    init(date: Date, calendar: Calendar = .current) {
        calendarIdentifier = calendar.identifier
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        era = components.era
        year = Self.required(components.year, component: "year")
        month = Self.required(components.month, component: "month")
        day = Self.required(components.day, component: "day")
    }

    var startDate: Date {
        let calendar = resolvedCalendar
        guard let date = calendar.date(from: dateComponents) else {
            preconditionFailure("CalendarDay contains invalid date components.")
        }

        return calendar.startOfDay(for: date)
    }

    var dayInterval: DayInterval {
        let calendar = resolvedCalendar
        let start = startDate
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            preconditionFailure("CalendarDay could not advance to the next day.")
        }
        return DayInterval(start: start, end: end)
    }

    var weekDays: [CalendarDay] {
        let calendar = resolvedCalendar
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: startDate) else {
            preconditionFailure("CalendarDay could not resolve a week interval.")
        }

        let weekStart = CalendarDay(date: interval.start, calendar: calendar)
        return (0..<7).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart.startDate) else {
                preconditionFailure("CalendarDay could not build week day \(offset).")
            }
            return CalendarDay(date: date, calendar: calendar)
        }
    }

    func advanced(byDays days: Int) -> CalendarDay? {
        resolvedCalendar.date(byAdding: .day, value: days, to: startDate).map {
            CalendarDay(date: $0, calendar: resolvedCalendar)
        }
    }

    func date(matchingTimeOf referenceDate: Date = .now) -> Date {
        let calendar = resolvedCalendar
        var components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: referenceDate)
        components.era = era
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else {
            preconditionFailure("CalendarDay could not combine date and time components.")
        }
        return date
    }

    var dayTitle: String {
        if isToday {
            return "Today"
        }

        return startDate.formatted(date: .abbreviated, time: .omitted)
    }

    var weekdayNarrowTitle: String {
        startDate.formatted(.dateTime.weekday(.narrow))
    }

    var weekdayAccessibilityTitle: String {
        startDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var topBarTitle: String {
        let start = startDate
        let dateTitle = start.formatted(.dateTime.month(.abbreviated).day().year())

        if isToday {
            return "Today, \(dateTitle)"
        }

        return "\(start.formatted(.dateTime.weekday(.wide))), \(dateTitle)"
    }

    var isToday: Bool {
        self == CalendarDay(date: Date(), calendar: resolvedCalendar)
    }

    private var dateComponents: DateComponents {
        var components = DateComponents()
        components.era = era
        components.year = year
        components.month = month
        components.day = day
        return components
    }

    private var resolvedCalendar: Calendar {
        var calendar = Calendar(identifier: calendarIdentifier)
        calendar.locale = .current
        calendar.timeZone = .current
        return calendar
    }

    private static func required(_ value: Int?, component: String) -> Int {
        guard let value else {
            preconditionFailure("CalendarDay requires a \(component) component.")
        }

        return value
    }
}

extension Date {
    var calendarDay: CalendarDay {
        CalendarDay(date: self)
    }

    var timeTitle: String {
        formatted(date: .omitted, time: .shortened)
    }
}
