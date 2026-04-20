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
        year = components.year ?? 0
        month = components.month ?? 1
        day = components.day ?? 1
    }

    var startDate: Date {
        let calendar = resolvedCalendar
        guard let date = calendar.date(from: dateComponents) else {
            return Date()
        }

        return calendar.startOfDay(for: date)
    }

    var dayInterval: DayInterval {
        let calendar = resolvedCalendar
        let start = startDate
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return DayInterval(start: start, end: end)
    }

    var weekDays: [CalendarDay] {
        let calendar = resolvedCalendar
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: startDate) else {
            return [self]
        }

        let weekStart = CalendarDay(date: interval.start, calendar: calendar)
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart.startDate).map {
                CalendarDay(date: $0, calendar: calendar)
            }
        }
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

    var historyNavigationTitle: String {
        let dateTitle = startDate.formatted(.dateTime.month(.abbreviated).day().year())

        if isToday {
            return "Today, \(dateTitle)"
        }

        return "\(startDate.formatted(.dateTime.weekday(.wide))), \(dateTitle)"
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
}

extension Date {
    var calendarDay: CalendarDay {
        CalendarDay(date: self)
    }

    var timeTitle: String {
        formatted(date: .omitted, time: .shortened)
    }
}
