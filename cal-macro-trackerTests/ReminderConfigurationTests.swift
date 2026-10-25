import XCTest
@testable import cal_macro_tracker

final class ReminderConfigurationTests: XCTestCase {
    func testFreeReminderIsLimitedToOne() {
        let reminders = ReminderScheduler.resolveReminders(
            free: reminder("Daily", hour: 20, minute: 0),
            pro: [reminder("Breakfast", hour: 8, minute: 0)],
            hasPro: false
        )

        XCTAssertEqual(reminders, [reminder("Daily", hour: 20, minute: 0)])
    }

    func testProRemindersAreCappedAtThreeAndDeduplicatedByTime() {
        let reminders = ReminderScheduler.resolveReminders(
            free: reminder("Daily", hour: 20, minute: 0),
            pro: [
                reminder("Breakfast", hour: 8, minute: 0),
                reminder("Lunch", hour: 12, minute: 30),
                reminder("Dinner", hour: 18, minute: 0),
                reminder("Evening", hour: 20, minute: 0)
            ],
            hasPro: true
        )

        XCTAssertEqual(reminders, [
            reminder("Breakfast", hour: 8, minute: 0),
            reminder("Lunch", hour: 12, minute: 30),
            reminder("Dinner", hour: 18, minute: 0)
        ])
    }

    func testDailyAndEveningRemindersDeduplicateByTime() {
        let reminders = ReminderScheduler.resolveReminders(
            free: reminder("Daily", hour: 20, minute: 0),
            pro: [reminder("Evening", hour: 20, minute: 0)],
            hasPro: true
        )

        XCTAssertEqual(reminders, [reminder("Evening", hour: 20, minute: 0)])
    }

    func testLoggedDayUsesCalendarLocalDayNearMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 23, minute: 59)))
        let loggedJustAfterMidnight = try XCTUnwrap(calendar.date(byAdding: .minute, value: 2, to: start))

        let days = ReminderScheduler.upcomingDays(
            from: start,
            count: 2,
            loggedDates: [loggedJustAfterMidnight],
            calendar: calendar
        )

        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(calendar.component(.day, from: days[0]), 25)
    }

    @MainActor
    func testOverlappingRefreshesRunOnlyLatestQueuedConfiguration() async {
        let coordinator = ReminderRefreshCoordinator()
        let firstStarted = expectation(description: "first refresh started")
        let releaseFirst = ReminderRefreshTestLatch()
        var completed: [String] = []

        coordinator.request {
            completed.append("first")
            firstStarted.fulfill()
            await releaseFirst.wait()
        }
        await fulfillment(of: [firstStarted])

        coordinator.request { completed.append("superseded") }
        coordinator.request { completed.append("latest") }
        await releaseFirst.release()
        await coordinator.waitUntilIdle()

        XCTAssertEqual(completed, ["first", "latest"])
    }

    private func reminder(_ title: String, hour: Int, minute: Int) -> ReminderDefinition {
        ReminderDefinition(title: title, hour: hour, minute: minute, onlyIfNothingLogged: false)
    }
}

private actor ReminderRefreshTestLatch {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isReleased = false

    func wait() async {
        guard !isReleased else { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        isReleased = true
        continuation?.resume()
        continuation = nil
    }
}
