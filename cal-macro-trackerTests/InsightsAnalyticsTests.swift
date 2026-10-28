import XCTest
@testable import cal_macro_tracker

final class InsightsAnalyticsTests: XCTestCase {
    // Chart failure modes: 90D/1Y/All aggregation; sparse logged days collapsing
    // together; missing dates becoming zeroes; month/leap/DST offsets; and
    // incomplete nutrients being presented as zero.
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
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = CalendarDay(date: date(year: 2026, month: 1, day: 3), calendar: calendar)

        XCTAssertEqual(InsightsRange.ninetyDays.days(endingOn: today).count, 90)
        let yearDays = InsightsRange.oneYear.days(endingOn: today)
        XCTAssertEqual(yearDays.count, 365)
        let previousDays = InsightsRange.oneYear.previousDays(endingBefore: today)
        XCTAssertEqual(previousDays.count, 365)
        XCTAssertEqual(previousDays.first, CalendarDay(date: date(year: 2024, month: 1, day: 5), calendar: calendar))
        XCTAssertEqual(previousDays.last, CalendarDay(date: date(year: 2025, month: 1, day: 3), calendar: calendar))
        XCTAssertEqual(yearDays.first, CalendarDay(date: date(year: 2025, month: 1, day: 4), calendar: calendar))
    }

    func testRepeatedRangeRequestsWithSameAnchorAreStable() {
        let today = CalendarDay(date: date(year: 2026, month: 5, day: 7))

        XCTAssertEqual(
            InsightsRange.oneYear.days(endingOn: today),
            InsightsRange.oneYear.days(endingOn: today)
        )
        XCTAssertEqual(
            InsightsRange.allTime.days(endingOn: today, startingAt: day(-12)),
            InsightsRange.allTime.days(endingOn: today, startingAt: day(-12))
        )
    }

    func testDailyChartBucketsOmitUnloggedDaysButKeepSummaryCoverage() {
        let points = [
            point(dayOffset: 0, calories: 2_000),
            emptyPoint(dayOffset: 1),
            point(dayOffset: 2, calories: 1_600)
        ]

        let buckets = InsightsAnalytics.chartPoints(for: points)
        let summary = InsightsAnalytics.metricSummary(current: points, previous: [], value: \.calories)

        XCTAssertEqual(buckets.map(\.totals.calories), [2_000, 1_600])
        XCTAssertEqual(buckets.map(\.loggedDayCount), [1, 1])
        XCTAssertEqual(points.count, 3)
        XCTAssertEqual(summary.totalDayCount, 3)
    }

    func testEveryInsightsRangeUsesDailyChartPoints() {
        for range in InsightsRange.allCases {
            let days = range.days(endingOn: day(0), startingAt: day(-2))
            let loggedPoints = [
                point(day: days[0], calories: 1_500),
                point(day: days[days.count - 1], calories: 1_700)
            ]

            let chartPoints = InsightsAnalytics.chartPoints(for: loggedPoints)

            XCTAssertEqual(chartPoints.map(\.day), [days[0], days[days.count - 1]], "\(range.title) should retain each logged day")
        }
    }

    func testSevenConsecutiveLoggedDaysRemainSevenDailyChartPoints() {
        let points = (0..<7).map { point(dayOffset: $0, calories: Double(1_500 + $0 * 100)) }

        let chartPoints = InsightsAnalytics.chartPoints(for: points)

        XCTAssertEqual(chartPoints.count, 7)
        XCTAssertEqual(chartPoints.map(\.totals.calories), [1_500, 1_600, 1_700, 1_800, 1_900, 2_000, 2_100])
        XCTAssertEqual(chartPoints.map(\.day), points.map(\.day))
    }

    func testSparseDailyChartPointsKeepCalendarDayPositionsAndOmitUnloggedDays() {
        let days = (0..<7).map { day($0) }
        let points = [
            point(day: days[0], calories: 1_500, fiber: nil),
            emptyPoint(dayOffset: 1),
            emptyPoint(dayOffset: 2),
            emptyPoint(dayOffset: 3),
            emptyPoint(dayOffset: 4),
            emptyPoint(dayOffset: 5),
            point(day: days[6], calories: 2_100, fiber: 0)
        ]
        let chartPoints = InsightsAnalytics.chartPoints(for: points)
        let indexed = chartPoints.indexedForCharts(startingAt: days[0])

        XCTAssertEqual(chartPoints.map(\.day), [days[0], days[6]])
        XCTAssertEqual(indexed.map(\.index), [0, 6])
        XCTAssertNil(chartPoints[0].secondaryTotals.fiber)
        XCTAssertEqual(chartPoints[1].secondaryTotals.fiber, 0)
    }

    func testChartAxisKeepsSevenDailyLabelsAndIncludesLastLongRangeDay() {
        XCTAssertEqual(InsightsChartAxis(dayCount: 7).labelIndices, Array(0...6))
        XCTAssertEqual(InsightsChartAxis(dayCount: 14).labelIndices.last, 13)

        let longRangeAxis = InsightsChartAxis(dayCount: 365)
        XCTAssertEqual(longRangeAxis.visibleDayCount, 30)
        XCTAssertTrue(longRangeAxis.usesHorizontalScrolling)
        XCTAssertEqual(longRangeAxis.labelIndices.last, 364)
    }

    func testChartSelectionDoesNotResolveOutsideCurrentCalendarDomain() {
        let axis = InsightsChartAxis(dayCount: 7)

        XCTAssertEqual(axis.selectedDayIndex(for: 0), 0)
        XCTAssertEqual(axis.selectedDayIndex(for: 6), 6)
        XCTAssertEqual(axis.selectedDayIndex(for: nil), nil)
        XCTAssertEqual(axis.selectedDayIndex(for: -1), nil)
        XCTAssertEqual(axis.selectedDayIndex(for: 7), nil)
    }

    func testLongRangeDaysStaySeparateAcrossWeeksMonthsAndYears() {
        let start = CalendarDay(date: date(year: 2025, month: 1, day: 1))
        let offsets = [0, 8, 31, 90, 180, 364]
        let points = offsets.map { offset in
            point(day: start.advanced(byDays: offset)!, calories: Double(1_000 + offset))
        }

        let chartPoints = InsightsAnalytics.chartPoints(for: points)

        XCTAssertEqual(chartPoints.count, offsets.count)
        XCTAssertEqual(chartPoints.map(\.day), offsets.map { start.advanced(byDays: $0)! })
        XCTAssertEqual(chartPoints.map(\.totals.calories), offsets.map { Double(1_000 + $0) })
    }

    func testMultipleEntriesOnOneDateRemainOneCombinedDailyTotal() {
        let loggedDay = day(0)
        let days = [loggedDay]
        let entries = [
            entry(day: loggedDay, calories: 600),
            entry(day: loggedDay, calories: 900)
        ]

        let points = InsightsAnalytics.points(for: entries, days: days)
        let chartPoints = InsightsAnalytics.chartPoints(for: points)

        XCTAssertEqual(chartPoints.count, 1)
        XCTAssertEqual(chartPoints[0].totals.calories, 1_500)
    }

    func testDailyChartOffsetsRespectCalendarAcrossMonthLeapAndDSTBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let dates = [
            date(year: 2024, month: 2, day: 28),
            date(year: 2024, month: 2, day: 29),
            date(year: 2024, month: 3, day: 1),
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 7))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 8))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 9))!
        ]
        let days = dates.map { CalendarDay(date: $0, calendar: calendar) }

        XCTAssertEqual(
            InsightsAnalytics.chartPoints(for: [point(day: days[1]), point(day: days[2])])
                .indexedForCharts(startingAt: days[0]).map(\.index),
            [1, 2]
        )
        XCTAssertEqual(
            InsightsAnalytics.chartPoints(for: [point(day: days[4]), point(day: days[5])])
                .indexedForCharts(startingAt: days[3]).map(\.index),
            [1, 2]
        )
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
        InsightsDayPoint(day: day, snapshot: LogEntryDaySummary.snapshot(for: [entry(day: day, calories: calories, protein: protein, fat: fat, carbs: carbs, fiber: fiber)]))
    }

    private func entry(
        day: CalendarDay,
        calories: Double = 0,
        protein: Double = 0,
        fat: Double = 0,
        carbs: Double = 0,
        fiber: Double? = nil
    ) -> LogEntry {
        LogEntry(
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
