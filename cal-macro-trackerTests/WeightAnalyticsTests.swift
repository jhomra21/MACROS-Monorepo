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
