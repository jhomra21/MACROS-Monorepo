import XCTest
@testable import cal_macro_tracker

final class InsightsAnalyticsTests: XCTestCase {
    func testRangeBuildsRollingDaysEndingToday() {
        let today = CalendarDay(date: date(year: 2026, month: 5, day: 7))

        let days = InsightsRange.sevenDays.days(endingOn: today)

        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first, CalendarDay(date: date(year: 2026, month: 5, day: 1)))
        XCTAssertEqual(days.last, today)
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
        let entry = LogEntry(
            dateLogged: day(dayOffset).startDate,
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

        return InsightsDayPoint(day: day(dayOffset), snapshot: LogEntryDaySummary.snapshot(for: [entry]))
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
