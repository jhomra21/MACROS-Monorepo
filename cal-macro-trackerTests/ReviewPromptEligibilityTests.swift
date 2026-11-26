import XCTest
@testable import cal_macro_tracker

final class ReviewPromptEligibilityTests: XCTestCase {
    func testBaselineEligibilityAfterFiveEntriesAcrossThreeDays() {
        let today = CalendarDay(date: date(2026, 11, 25))
        XCTAssertTrue(eligible([0, 0, 1, 2, 10], today: today))
    }

    func testPositiveMomentEligibilityAfterThreeConsecutiveDays() {
        let today = CalendarDay(date: date(2026, 11, 25))
        XCTAssertTrue(eligible([0, 1, 2], today: today))
        XCTAssertTrue(eligible(Array(0...6), today: today))
    }

    func testRequiresVersionSpacingAndRecentUseGates() {
        let today = CalendarDay(date: date(2026, 11, 25))
        XCTAssertFalse(eligible([0, 1, 2], today: today, promptedVersion: "1.0"))
        XCTAssertFalse(eligible([0, 1, 2], today: today, lastRequestedAt: date(2026, 11, 12)))
        XCTAssertTrue(eligible([0, 1, 2], today: today, lastRequestedAt: date(2026, 11, 11)))
        XCTAssertFalse(eligible([2, 3, 100], today: today))
    }

    private func eligible(
        _ offsets: [Int],
        today: CalendarDay,
        promptedVersion: String = "",
        lastRequestedAt: Date? = nil
    ) -> Bool {
        ReviewPromptEligibility.isEligible(
            entryDays: offsets.compactMap { today.advanced(byDays: -$0) },
            today: today,
            promptedVersion: promptedVersion,
            lastRequestedAt: lastRequestedAt,
            appVersion: "1.1",
            now: date(2026, 11, 25)
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))!
    }
}
