import SwiftData
import XCTest
@testable import cal_macro_tracker

final class LogEntryQueryTests: XCTestCase {
    func testCapturedHistoryWeekQueryUsesDSTAwareFinalDayBoundary() throws {
        try assertHistoryWeekQuery(
            endingOn: (month: 11, day: 1),
            weekStart: (month: 10, day: 26),
            expectedHours: 25,
            lateEntry: (hour: 23, minute: 30)
        )
    }

    func testCapturedHistoryWeekQueryExcludesNextMidnightAfterSpringForward() throws {
        try assertHistoryWeekQuery(
            endingOn: (month: 3, day: 8),
            weekStart: (month: 3, day: 2),
            expectedHours: 23,
            lateEntry: (hour: 23, minute: 30)
        )
    }

    func testCapturedHistoryWeekQueryUsesNormalTwentyFourHourBoundary() throws {
        try assertHistoryWeekQuery(
            endingOn: (month: 10, day: 25),
            weekStart: (month: 10, day: 19),
            expectedHours: 24,
            lateEntry: (hour: 23, minute: 30)
        )
    }

    private func assertHistoryWeekQuery(
        endingOn finalDayComponents: (month: Int, day: Int),
        weekStart startComponents: (month: Int, day: Int),
        expectedHours: Int,
        lateEntry: (hour: Int, minute: Int),
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        var capturedCalendar = Calendar(identifier: .gregorian)
        capturedCalendar.locale = Locale(identifier: "en_GB")
        capturedCalendar.timeZone = TimeZone(identifier: "America/New_York")!
        let weekStart = capturedCalendar.date(
            from: DateComponents(year: 2026, month: startComponents.month, day: startComponents.day, hour: 12)
        )!
        let days = (0..<7).map { offset in
            CalendarDay(date: capturedCalendar.date(byAdding: .day, value: offset, to: weekStart)!, calendar: capturedCalendar)
        }
        let finalDay = days.last!
        XCTAssertEqual(
            finalDay.dayInterval.end.timeIntervalSince(finalDay.startDate),
            Double(expectedHours * 3_600),
            file: file,
            line: line
        )

        var effectiveCalendar = Calendar(identifier: .gregorian)
        effectiveCalendar.locale = Locale(identifier: "en_GB")
        effectiveCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let initialToday = CalendarDay(
            date: capturedCalendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 12))!,
            calendar: capturedCalendar
        )
        let effectiveToday = CalendarDay(
            date: effectiveCalendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 12))!,
            calendar: effectiveCalendar
        )
        var selection = AppDaySelection(today: initialToday)
        let selectedHistoricalDay = days[2]
        selection.select(selectedHistoricalDay, today: initialToday)
        selection.syncToday(from: initialToday, to: effectiveToday)
        XCTAssertEqual(selection.selectedDay, selectedHistoricalDay, file: file, line: line)

        let finalStart = finalDay.startDate
        let lateLogDate = capturedCalendar.date(
            bySettingHour: lateEntry.hour,
            minute: lateEntry.minute,
            second: 0,
            of: finalDay.startDate
        )!
        let nextMidnight = finalDay.dayInterval.end
        XCTAssertGreaterThanOrEqual(lateLogDate, finalStart, file: file, line: line)
        XCTAssertLessThan(lateLogDate, nextMidnight, file: file, line: line)

        let container = try ModelContainer(
            for: LogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = ModelContext(container)
        context.insert(makeEntry(named: "late final-day log", at: lateLogDate))
        context.insert(makeEntry(named: "next midnight log", at: nextMidnight))
        try context.save()

        let entries = try context.fetch(
            LogEntryQuery.descriptor(for: days, fallbackDay: selection.selectedDay)
        )

        XCTAssertTrue(entries.contains(where: { $0.foodName == "late final-day log" }), file: file, line: line)
        XCTAssertFalse(entries.contains(where: { $0.foodName == "next midnight log" }), file: file, line: line)
    }

    private func makeEntry(named name: String, at date: Date) -> LogEntry {
        LogEntry(
            dateLogged: date,
            foodName: name,
            source: .custom,
            servingDescription: "1 serving",
            caloriesPerServing: 0,
            proteinPerServing: 0,
            fatPerServing: 0,
            carbsPerServing: 0,
            quantityMode: .servings,
            servingsConsumed: 1,
            caloriesConsumed: 0,
            proteinConsumed: 0,
            fatConsumed: 0,
            carbsConsumed: 0
        )
    }
}
