import XCTest
@testable import cal_macro_tracker

final class ReminderSchedulerTests: XCTestCase {
    func testSelectsUpcomingDaysChronologicallyAndSkipsLoggedDays() {
        let start = date(2026, 10, 25, 12)
        let logged = [date(2026, 10, 26, 8), date(2026, 10, 28, 20)]

        let days = ReminderScheduler.upcomingDays(
            from: start,
            count: 7,
            loggedDates: logged,
            calendar: calendar
        )

        XCTAssertEqual(days, [
            date(2026, 10, 25, 12),
            date(2026, 10, 27, 12),
            date(2026, 10, 29, 12),
            date(2026, 10, 30, 12),
            date(2026, 10, 31, 12)
        ].map { calendar.startOfDay(for: $0) })
    }

    func testZeroHorizonReturnsNoDays() {
        XCTAssertEqual(
            ReminderScheduler.upcomingDays(from: date(2026, 10, 25, 12), count: 0, loggedDates: [], calendar: calendar),
            []
        )
    }

    func testUsesCalendarDaysAcrossDSTTransition() throws {
        var daylightSavingCalendar = Calendar(identifier: .gregorian)
        daylightSavingCalendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let start = date(2026, 10, 31, 12, calendar: daylightSavingCalendar)

        let days = ReminderScheduler.upcomingDays(
            from: start,
            count: 3,
            loggedDates: [],
            calendar: daylightSavingCalendar
        )

        XCTAssertEqual(days.count, 3)
        XCTAssertEqual(daylightSavingCalendar.component(.hour, from: days[1]), 0)
        XCTAssertEqual(days[1], daylightSavingCalendar.startOfDay(for: date(2026, 11, 1, 12, calendar: daylightSavingCalendar)))
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, calendar: Calendar? = nil) -> Date {
        (calendar ?? self.calendar).date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
