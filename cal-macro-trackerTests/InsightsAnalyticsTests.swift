import XCTest
@testable import cal_macro_tracker

final class InsightsAnalyticsTests: XCTestCase {
    // Streak failure cases: no entries; a gap before today; yesterday-only logging;
    // and dates straddling UTC midnight in the app calendar's time zone.
    func testCurrentStreakIsZeroWithoutEntries() {
        let today = day(0)

        XCTAssertEqual(InsightsAnalytics.currentStreak(days: [], today: today), 0)
    }

    func testCurrentStreakStopsAtGapBeforeToday() {
        let today = day(0)
        let points = [day(-2), today]

        XCTAssertEqual(InsightsAnalytics.currentStreak(days: points, today: today), 1)
    }

    func testCurrentStreakIncludesYesterdayWhenTodayIsEmpty() {
        let today = day(0)
        let points = [today.advanced(byDays: -1)!]

        XCTAssertEqual(InsightsAnalytics.currentStreak(days: points, today: today), 1)
    }

    func testCurrentStreakUsesAppCalendarTimeZoneAtDateBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: -8 * 60 * 60)!
        let beforeLocalMidnight = CalendarDay(
            date: date(year: 2026, month: 5, day: 7).addingTimeInterval(7.5 * 60 * 60),
            calendar: calendar
        )
        let afterLocalMidnight = CalendarDay(
            date: date(year: 2026, month: 5, day: 7).addingTimeInterval(8.5 * 60 * 60),
            calendar: calendar
        )

        XCTAssertNotEqual(beforeLocalMidnight, afterLocalMidnight)
        XCTAssertEqual(InsightsAnalytics.currentStreak(days: [beforeLocalMidnight, afterLocalMidnight], today: afterLocalMidnight), 2)
    }

    func testRangeBuildsRollingDaysEndingToday() {
        let today = CalendarDay(date: date(year: 2026, month: 5, day: 7))

        let days = InsightsRange.sevenDays.days(endingOn: today)

        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first, CalendarDay(date: date(year: 2026, month: 5, day: 1)))
        XCTAssertEqual(days.last, today)
    }

    func testAllTimeDaysAreEmptyWithoutAnEarliestEntry() {
        let today = CalendarDay(date: date(year: 2026, month: 5, day: 7))

        XCTAssertTrue(InsightsRange.allTime.days(endingOn: today, startingAt: nil).isEmpty)
        XCTAssertTrue(InsightsRange.allTime.previousDays(endingBefore: today).isEmpty)
    }

    func testAllTimeDaysIncludeEarliestEntryThroughToday() {
        let today = CalendarDay(date: date(year: 2026, month: 5, day: 7))
        let earliest = CalendarDay(date: date(year: 2026, month: 5, day: 5))

        XCTAssertEqual(InsightsRange.allTime.days(endingOn: today, startingAt: earliest), [earliest, earliest.advanced(byDays: 1)!, today])
    }

    func testLongFixedRangesPreserveCalendarDayCountAndPreviousPeriod() {
        let today = CalendarDay(date: date(year: 2026, month: 1, day: 3))

        XCTAssertEqual(InsightsRange.ninetyDays.days(endingOn: today).count, 90)
        let yearDays = InsightsRange.oneYear.days(endingOn: today)
        XCTAssertEqual(yearDays.count, 365)
        XCTAssertEqual(InsightsRange.oneYear.previousDays(endingBefore: today).count, 365)
        XCTAssertEqual(InsightsRange.oneYear.previousDays(endingBefore: today).last, yearDays.first?.advanced(byDays: -1))
    }

    func testChartBucketsAverageOnlyLoggedDaysAndKeepMissingNutrientsMissing() {
        let points = [
            point(dayOffset: 0, calories: 2_000, protein: 100, fiber: 20),
            emptyPoint(dayOffset: 1),
            point(dayOffset: 2, calories: 1_600, protein: 80, fiber: nil)
        ]

        let buckets = InsightsAnalytics.chartPoints(for: points, bucket: .weekly)

        XCTAssertEqual(buckets.count, 1)
        XCTAssertEqual(buckets[0].totals.calories, 1_800)
        XCTAssertEqual(buckets[0].totals.protein, 90)
        XCTAssertEqual(buckets[0].secondaryTotals.fiber, 20)
        XCTAssertEqual(buckets[0].loggedDayCount, 2)
    }

    func testChartBucketingKeepsOneLoggedDayAndSeparatesMonthBoundaries() {
        let points = [
            point(date: date(year: 2024, month: 2, day: 29), calories: 2_100),
            point(date: date(year: 2024, month: 3, day: 1), calories: 1_900)
        ]

        let buckets = InsightsAnalytics.chartPoints(for: points, bucket: .monthly)

        XCTAssertEqual(buckets.count, 2)
        XCTAssertEqual(buckets.map(\.totals.calories), [2_100, 1_900])
        XCTAssertEqual(buckets.map(\.loggedDayCount), [1, 1])
    }

    func testWeeklyChartBucketingHandlesDaylightSavingBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let march8 = CalendarDay(
            date: calendar.date(from: DateComponents(year: 2026, month: 3, day: 8))!,
            calendar: calendar
        )
        let points = [
            point(day: march8, calories: 2_000),
            point(day: march8.advanced(byDays: 1)!, calories: 1_800)
        ]

        let buckets = InsightsAnalytics.chartPoints(for: points, bucket: .weekly)

        XCTAssertEqual(buckets.count, 1)
        XCTAssertEqual(buckets[0].totals.calories, 1_900)
    }

    func testAverageExcludesDaysWithoutEntries() {
        let points = [
            point(dayOffset: 0, calories: 2_000, protein: 150),
            emptyPoint(dayOffset: 1),
            point(dayOffset: 2, calories: 1_600, protein: 110)
        ]

        let summary = InsightsAnalytics.metricSummary(current: points, previous: [], value: \.calories)

        XCTAssertEqual(summary.average, 1_800)
        XCTAssertEqual(summary.loggedDayCount, 2)
        XCTAssertEqual(summary.totalDayCount, 3)
    }

    func testPreviousPeriodComparisonUsesPreviousAverage() {
        let current = [point(dayOffset: 0, calories: 2_200, protein: 120)]
        let previous = [point(dayOffset: -1, calories: 2_000, protein: 100)]

        let summary = InsightsAnalytics.metricSummary(current: current, previous: previous, value: \.calories)

        XCTAssertEqual(summary.comparisonPercent, 10)
    }

    func testSecondaryNutrientCoverageExcludesMissingValuesButKeepsZero() {
        let points = [
            point(dayOffset: 0, fiber: 20),
            point(dayOffset: 1, fiber: nil),
            point(dayOffset: 2, fiber: 0)
        ]

        let summary = InsightsAnalytics.nutrientSummary(current: points, previous: [], nutrient: .fiber)

        XCTAssertEqual(summary.average, 10)
        XCTAssertEqual(summary.availableDayCount, 2)
        XCTAssertEqual(summary.loggedDayCount, 3)
    }

    func testCalorieAdherenceUsesTenPercentTargetRange() {
        let points = [
            point(dayOffset: 0, calories: 1_800, protein: 90),
            point(dayOffset: 1, calories: 2_200, protein: 90),
            point(dayOffset: 2, calories: 2_250, protein: 90)
        ]

        let adherence = InsightsAnalytics.calorieAdherence(in: points, calorieGoal: 2_000)

        XCTAssertEqual(adherence.successfulDays, 2)
        XCTAssertEqual(adherence.loggedDayCount, 3)
    }

    func testProteinAdherenceCountsAtLeastGoal() {
        let points = [
            point(dayOffset: 0, calories: 2_000, protein: 149),
            point(dayOffset: 1, calories: 2_000, protein: 150),
            point(dayOffset: 2, calories: 2_000, protein: 180)
        ]

        let adherence = InsightsAnalytics.proteinAdherence(in: points, proteinGoal: 150)

        XCTAssertEqual(adherence.successfulDays, 2)
        XCTAssertEqual(adherence.loggedDayCount, 3)
    }

    private func emptyPoint(dayOffset: Int) -> InsightsDayPoint {
        InsightsDayPoint(day: day(dayOffset), snapshot: .empty)
    }

    private func point(
        dayOffset: Int,
        calories: Double = 0,
        protein: Double = 0,
        fat: Double = 0,
        carbs: Double = 0,
        fiber: Double? = nil
    ) -> InsightsDayPoint {
        point(day: day(dayOffset), calories: calories, protein: protein, fat: fat, carbs: carbs, fiber: fiber)
    }

    private func point(date: Date, calories: Double) -> InsightsDayPoint {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return point(day: CalendarDay(date: date, calendar: calendar), calories: calories)
    }

    private func point(
        day: CalendarDay,
        calories: Double = 0,
        protein: Double = 0,
        fat: Double = 0,
        carbs: Double = 0,
        fiber: Double? = nil
    ) -> InsightsDayPoint {
        let entry = LogEntry(
            dateLogged: day.startDate,
            foodName: "Test Food",
            source: .custom,
            servingDescription: "1 serving",
            caloriesPerServing: calories,
            proteinPerServing: protein,
            fatPerServing: fat,
            carbsPerServing: carbs,
            fiberPerServing: fiber,
            quantityMode: .servings,
            servingsConsumed: 1,
            caloriesConsumed: calories,
            proteinConsumed: protein,
            fatConsumed: fat,
            carbsConsumed: carbs,
            fiberConsumed: fiber
        )

        return InsightsDayPoint(day: day, snapshot: LogEntryDaySummary.snapshot(for: [entry]))
    }

    private func day(_ offset: Int) -> CalendarDay {
        let calendar = Calendar(identifier: .gregorian)
        let baseDate = date(year: 2026, month: 5, day: 7)
        return CalendarDay(date: calendar.date(byAdding: .day, value: offset, to: baseDate)!)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        return components.date!
    }
}
