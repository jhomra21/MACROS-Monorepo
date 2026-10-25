import XCTest
@testable import cal_macro_tracker

final class WeightAnalyticsTests: XCTestCase {
    func testEmptyHistoryHasNoLatestOrTrend() {
        XCTAssertNil(WeightAnalytics.latest(from: []))
        XCTAssertTrue(WeightAnalytics.movingAverages(from: [], calendar: calendar).isEmpty)
        XCTAssertNil(WeightAnalytics.weeklyRate(from: []))
    }

    func testLatestAndTrendResolveOutOfOrderDuplicateDaysByRecordedDate() {
        let entries = [
            entry(day: date(2026, 10, 2), recordedAt: date(2026, 10, 2), kg: 70),
            entry(day: date(2026, 10, 1), recordedAt: date(2026, 10, 1), kg: 72),
            entry(day: date(2026, 10, 2), recordedAt: date(2026, 10, 3), kg: 71)
        ]

        XCTAssertEqual(WeightAnalytics.latest(from: entries)?.weightKg, 71)
        XCTAssertEqual(
            WeightAnalytics.movingAverages(from: entries, calendar: calendar).map(\.averageKg),
            [72, 71.5]
        )
    }

    func testMovingAverageUsesAvailableValuesAndSkipsInvalidWeights() {
        let entries = [
            entry(day: date(2026, 10, 1), recordedAt: date(2026, 10, 1), kg: 70),
            entry(day: date(2026, 10, 3), recordedAt: date(2026, 10, 3), kg: 72),
            entry(day: date(2026, 10, 4), recordedAt: date(2026, 10, 4), kg: .nan),
            entry(day: date(2026, 10, 5), recordedAt: date(2026, 10, 5), kg: 0)
        ]

        let averages = WeightAnalytics.movingAverages(from: entries, calendar: calendar)

        XCTAssertEqual(averages.count, 2)
        XCTAssertEqual(averages[0].averageKg, 70)
        XCTAssertEqual(averages[1].averageKg, 71)
    }

    func testWeeklyRateNeedsValidEndpointsAndScalesByElapsedDays() {
        let entries = [
            entry(day: date(2026, 10, 1), recordedAt: date(2026, 10, 1), kg: 70),
            entry(day: date(2026, 10, 4), recordedAt: date(2026, 10, 4), kg: 69)
        ]

        XCTAssertEqual(
            try XCTUnwrap(WeightAnalytics.weeklyRate(from: entries, calendar: calendar)),
            -7.0 / 3.0,
            accuracy: 0.0001
        )
        XCTAssertNil(WeightAnalytics.weeklyRate(from: [entries[0]], calendar: calendar))
    }

    func testSevenDayChangeRequiresMatchingCalendarDay() {
        let latestDate = date(2026, 10, 8)
        let points = [
            entry(day: date(2026, 10, 1), recordedAt: date(2026, 10, 1), kg: 70),
            entry(day: date(2026, 10, 8), recordedAt: date(2026, 10, 8), kg: 69)
        ]

        XCTAssertEqual(
            WeightAnalytics.changeFromSevenDaysAgo(in: points, endingOn: latestDate, calendar: calendar),
            -1
        )
    }

    func testSevenDayChangeDoesNotUseAnArbitrarilyOldEntry() {
        let latestDate = date(2026, 10, 30)
        let points = [
            entry(day: date(2026, 10, 1), recordedAt: date(2026, 10, 1), kg: 70),
            entry(day: latestDate, recordedAt: latestDate, kg: 69)
        ]

        XCTAssertNil(WeightAnalytics.changeFromSevenDaysAgo(in: points, endingOn: latestDate, calendar: calendar))
    }

    func testMovingAverageUsesSlidingWindowAcrossLongHistory() {
        let points = (0..<30).map { offset in
            let day = date(2026, 10, 1).addingTimeInterval(Double(offset) * 86_400)
            return entry(day: day, recordedAt: day, kg: Double(offset + 1))
        }

        let averages = WeightAnalytics.movingAverages(from: points, calendar: calendar)

        XCTAssertEqual(averages.count, 30)
        XCTAssertEqual(averages[6].averageKg, 4)
        XCTAssertEqual(averages[29].averageKg, 27)
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func entry(day: Date, recordedAt: Date, kg: Double) -> WeightAnalyticsPoint {
        WeightAnalyticsPoint(day: day, recordedAt: recordedAt, weightKg: kg)
    }
}
