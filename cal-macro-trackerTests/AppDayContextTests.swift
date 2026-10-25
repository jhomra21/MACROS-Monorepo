import XCTest
@testable import cal_macro_tracker

@MainActor
final class AppDayContextTests: XCTestCase {
    func testDayIntervalAndAdvanceAcrossLocalDSTDates() {
        for (month, day) in [(3, 8), (11, 1)] {
            let value = date(year: 2026, month: month, day: day, hour: 12)
            let calendar = Calendar.current
            let interval = calendar.dateInterval(of: .day, for: value)!
            let calendarDay = CalendarDay(date: value, calendar: calendar)
            XCTAssertEqual(calendarDay.dayInterval.start, interval.start)
            XCTAssertEqual(calendarDay.dayInterval.end, interval.end)
            XCTAssertEqual(calendarDay.advanced(byDays: 1)?.startDate, interval.end)
        }
    }

    func testExplicitCalendarTimeZoneIsPreservedInDayInterval() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        let value = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12))!
        let day = CalendarDay(date: value, calendar: calendar)
        XCTAssertEqual(day.startDate, calendar.startOfDay(for: value))
        XCTAssertEqual(day.dayInterval.end, calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: value)))
    }

    func testHistoricalDayTitlesUseCapturedCalendarAndLocale() {
        var auckland = Calendar(identifier: .gregorian)
        auckland.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        auckland.locale = Locale(identifier: "en_US")
        let selectedDate = auckland.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 12))!
        let selectedDay = CalendarDay(date: selectedDate, calendar: auckland)

        var honolulu = Calendar(identifier: .gregorian)
        honolulu.timeZone = TimeZone(identifier: "Pacific/Honolulu")!
        let today = AppDayContext()
        today.refresh(using: selectedDate, calendar: honolulu)

        XCTAssertEqual(CalendarDay(date: today.today.startDate, calendar: honolulu).day, 9)
        XCTAssertEqual(selectedDay.startDate, auckland.startOfDay(for: selectedDate))
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(selectedDay.dayTitle(locale: locale), "Jun 10, 2026")
        XCTAssertEqual(selectedDay.weekdayNarrowTitle(locale: locale), "W")
        XCTAssertEqual(selectedDay.weekdayAccessibilityTitle(locale: locale), "Wednesday, June 10")
        XCTAssertEqual(selectedDay.topBarTitle(locale: locale), "Wednesday, Jun 10, 2026")
    }

    func testExplicitDSTIntervalsAre23And25Hours() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        for (month, day, hours) in [(3, 8, 23), (11, 1, 25)] {
            let date = calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
            let value = CalendarDay(date: date, calendar: calendar)
            XCTAssertEqual(value.dayInterval.end.timeIntervalSince(value.startDate), Double(hours * 3600))
            XCTAssertEqual(value.advanced(byDays: 1)?.startDate, value.dayInterval.end)
        }
    }

    func testCurrentCalendarAndTimezoneChangeEquality() {
        let date = Date.now
        XCTAssertEqual(CalendarDay(date: date).startDate, Calendar.current.startOfDay(for: date))
        var first = Calendar(identifier: .gregorian)
        first.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        var second = first
        second.timeZone = TimeZone(identifier: "Pacific/Honolulu")!
        let localNoon = DateComponents(year: 2026, month: 3, day: 8, hour: 12)
        let a = CalendarDay(date: first.date(from: localNoon)!, calendar: first)
        let b = CalendarDay(date: second.date(from: localNoon)!, calendar: second)
        XCTAssertNotEqual(a, b)
        var selected = AppDaySelection(today: a)
        selected.syncToday(from: a, to: b)
        XCTAssertEqual(selected.selectedDay, b)
        selected.select(a.advanced(byDays: -7)!, today: b)
        let historical = selected.selectedDay
        selected.syncToday(from: b, to: a)
        XCTAssertEqual(selected.selectedDay, historical)
    }

    func testRefreshUpdatesTodayFromControlledDate() {
        let context = AppDayContext()
        let controlledDate = date(year: 2026, month: 3, day: 8, hour: 12)

        context.refresh(using: controlledDate)

        XCTAssertEqual(context.today, CalendarDay(date: controlledDate))
    }

    func testEffectiveTimezoneRefreshUpdatesTodayWithoutChangingHost() {
        let context = AppDayContext()
        let date = Date.now
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        context.refresh(using: date, calendar: calendar)
        XCTAssertEqual(context.today, CalendarDay(date: date, calendar: calendar))
        calendar.timeZone = TimeZone(identifier: "Pacific/Honolulu")!
        context.refresh(using: date, calendar: calendar)
        XCTAssertEqual(context.today, CalendarDay(date: date, calendar: calendar))
    }

    func testDaySelectionTracksTodayOnlyUntilHistoricalDayIsSelected() {
        let initialDay = CalendarDay(date: date(year: 2026, month: 3, day: 7, hour: 12))
        let nextDay = CalendarDay(date: date(year: 2026, month: 3, day: 8, hour: 12))
        let historicalDay = CalendarDay(date: date(year: 2026, month: 3, day: 1, hour: 12))
        var selection = AppDaySelection(today: initialDay)

        selection.syncToday(from: initialDay, to: nextDay)
        XCTAssertEqual(selection.selectedDay, nextDay)
        XCTAssertTrue(selection.followsCurrentDay)

        selection.select(historicalDay, today: nextDay)
        selection.syncToday(from: nextDay, to: nextDay.advanced(byDays: 1)!)

        XCTAssertEqual(selection.selectedDay, historicalDay)
        XCTAssertFalse(selection.followsCurrentDay)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date!
    }
}
