import Foundation
import SwiftUI

struct AppDaySelection: Equatable {
    private(set) var selectedDay: CalendarDay
    private(set) var followsCurrentDay: Bool

    init(today: CalendarDay) {
        selectedDay = today
        followsCurrentDay = true
    }

    mutating func select(_ newDay: CalendarDay, today: CalendarDay, allowsFutureDays: Bool = false) {
        let boundedDay = allowsFutureDays ? newDay : bounded(day: newDay, maximumDay: today)
        selectedDay = boundedDay
        followsCurrentDay = boundedDay == today
    }

    mutating func resetToToday(_ today: CalendarDay) {
        select(today, today: today)
    }

    mutating func syncToday(from oldToday: CalendarDay, to newToday: CalendarDay) {
        if followsCurrentDay || selectedDay == oldToday {
            selectedDay = newToday
        }
        followsCurrentDay = selectedDay == newToday
    }

    private func bounded(day: CalendarDay, maximumDay: CalendarDay) -> CalendarDay {
        guard day.startDate > maximumDay.startDate else { return day }
        return maximumDay
    }
}

@MainActor
@Observable
final class AppDayContext {
    private(set) var today = CalendarDay(date: .now)

    func refresh(using date: Date = .now) {
        today = CalendarDay(date: date)
    }
}
