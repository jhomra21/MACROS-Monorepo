import XCTest
@testable import cal_macro_tracker

/// November 2026: Mon 23, Tue 24, Wed 25 (default today), Thu 26, Fri 27, Sat 28, Sun 29. Mon 16 starts the week before.
/// Failure list: build/evidence/2026-11-25-streaks/failure-list.md.
final class LoggingStreakSummaryTests: XCTestCase {
    private func calendar(_ identifier: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func date(
        _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0, second: Int = 0, year: Int = 2026,
        calendar: Calendar? = nil
    ) -> Date {
        let calendar = calendar ?? self.calendar()
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    /// An entry logged on November `day` at noon, created at `createdAt` (default: when it was logged).
    private func entry(_ day: Int, createdAt: Date? = nil) -> LoggingStreakEntry {
        LoggingStreakEntry(dateLogged: date(11, day), createdAt: createdAt ?? date(11, day))
    }

    private func summary(
        _ days: [Int], today: Int = 25, flex: [Int] = [], extra: [LoggingStreakEntry] = []
    ) -> LoggingStreakSummary {
        let calendar = calendar()
        return LoggingStreakSummary.make(
            entries: days.map { entry($0) } + extra,
            today: CalendarDay(date: date(11, today), calendar: calendar),
            flexDays: Set(flex.map { CalendarDay(date: date(11, $0), calendar: calendar) })
        )
    }

    private func currentWeekStates(_ summary: LoggingStreakSummary) -> [LoggingStreakSummary.DayState] {
        summary.currentWeek.map(\.state)
    }

    func testEmptyHistoryHasNoStreakAndNoMissedDays() {
        let summary = summary([])

        XCTAssertEqual([summary.current, summary.best, summary.totalLoggedDays], [0, 0, 0])
        XCTAssertNil(summary.lastCountedDay)
        XCTAssertEqual(summary.weeks.map(\.count), [7, 7, 7, 7])
        XCTAssertTrue(summary.weeks.joined().allSatisfy { $0.state == .future })
    }

    func testWeeksRunMondayToSundayStartingWithTheCurrentWeek() {
        let summary = summary([24])

        XCTAssertEqual(summary.currentWeek.map(\.day.sharingDayKey).first, "2026-11-23")
        XCTAssertEqual(summary.currentWeek.map(\.day.sharingDayKey).last, "2026-11-29")
        XCTAssertEqual(summary.weeks[3].first?.day.sharingDayKey, "2026-11-02")
    }

    func testYesterdayIsNotMissedUntilTodayEnds() {
        let summary = summary([22, 23])

        XCTAssertEqual(summary.current, 2)
        XCTAssertEqual(currentWeekStates(summary), [.logged, .future, .future, .future, .future, .future, .future])
    }

    func testStreakSurvivesOneMissedDayThroughTheWeeklyFlexDay() {
        // Tue 24 is the first settled miss of the week, so it becomes the flex day on Thu 26.
        let summary = summary([22, 23, 25, 26], today: 26)

        XCTAssertEqual(summary.current, 4)
        XCTAssertEqual(currentWeekStates(summary), [.logged, .flex, .logged, .logged, .future, .future, .future])
    }

    func testSecondMissInTheSameWeekBreaksTheStreak() {
        let summary = summary([22, 23, 26], today: 27)

        XCTAssertEqual(currentWeekStates(summary), [.logged, .flex, .missed, .logged, .future, .future, .future])
        XCTAssertEqual(summary.current, 1)
        XCTAssertEqual(summary.best, 2)
    }

    func testFlexDayBridgesWithoutAddingToTheStreak() {
        let summary = summary([22, 23, 25], today: 26)

        XCTAssertEqual(summary.current, 3, "22, 23 and 25 count; the flex day 24 adds nothing")
    }

    func testMarkedFlexDayShowsAheadOfTimeAndBridgesWhenUnlogged() {
        let ahead = summary([22, 23, 24, 25], flex: [27])
        XCTAssertEqual(currentWeekStates(ahead)[4], .flex)
        XCTAssertEqual(ahead.current, 4)

        let used = summary([22, 23, 24, 25, 26], today: 28, flex: [27])
        XCTAssertEqual(currentWeekStates(used)[4], .flex)
        XCTAssertEqual(used.current, 5)
    }

    func testMarkedFlexDayTakesTheWeeksAllowanceFromTheAutomaticOne() {
        // 24 is missed first, but the user marked Fri 27 for the week, so 24 breaks the streak.
        let summary = summary([22, 23, 25, 26], today: 26, flex: [27])

        XCTAssertEqual(currentWeekStates(summary), [.logged, .missed, .logged, .logged, .flex, .future, .future])
        XCTAssertEqual(summary.current, 2)
    }

    func testFlexDayMarkedOnALoggedDayStillCountsAndUsesTheAllowance() {
        let summary = summary([22, 23, 24, 26, 27], today: 27, flex: [24])

        XCTAssertEqual(currentWeekStates(summary), [.logged, .flex, .missed, .logged, .logged, .future, .future])
        XCTAssertEqual(summary.best, 3)
        XCTAssertEqual(summary.current, 2)
    }

    func testEachWeekGetsItsOwnFlexDayAcrossSundayToMonday() {
        // Sun 22 and Mon 23 are both missed, in different weeks, so both are bridged.
        let summary = summary([16, 17, 18, 19, 20, 21, 24, 25, 26], today: 26)

        XCTAssertEqual(summary.weeks[1].map(\.state).last, .flex)
        XCTAssertEqual(currentWeekStates(summary).first, .flex)
        XCTAssertEqual(summary.current, 9)
    }

    func testFortyEightHourBoundaryIsInclusive() {
        let calendar = calendar()
        let endOfFollowingDay = date(11, 25, hour: 0)
        let onTime = summary([], extra: [entry(23, createdAt: endOfFollowingDay)])
        let late = summary([], extra: [entry(23, createdAt: endOfFollowingDay.addingTimeInterval(1))])

        XCTAssertEqual(onTime.current, 1)
        XCTAssertEqual(onTime.lastCountedDay, CalendarDay(date: date(11, 23), calendar: calendar))
        XCTAssertEqual(late.current, 0)
        XCTAssertNil(late.lastCountedDay)
    }

    func testBackfillInsideTheWindowCountsAndOutsideOnlyAddsToTotal() {
        let inside = summary([], today: 25, extra: [entry(23, createdAt: date(11, 24, hour: 20))])
        XCTAssertEqual(inside.current, 1)

        let outside = summary([], today: 27, extra: [entry(23, createdAt: date(11, 26))])
        XCTAssertEqual(outside.current, 0)
        XCTAssertEqual(outside.best, 0)
        XCTAssertEqual(outside.totalLoggedDays, 1)
    }

    func testOneTimelyEntryCountsTheDayEvenWhenOthersAreLate() {
        let summary = summary([23], extra: [entry(23, createdAt: date(11, 28))])

        XCTAssertEqual(summary.current, 1)
    }

    func testDaysBeforeTheFirstCountedDayAreNotMissed() {
        let summary = summary([24])

        XCTAssertEqual(currentWeekStates(summary), [.future, .logged, .future, .future, .future, .future, .future])
        XCTAssertTrue(summary.weeks.dropFirst().joined().allSatisfy { $0.state == .future })
    }

    func testStaleStreakFallsToZeroAfterTheWindowAndKeepsBest() {
        let summary = summary([1, 2, 3, 4, 5], today: 25)

        XCTAssertEqual(summary.current, 0)
        XCTAssertEqual(summary.best, 5)
    }

    func testStreakCountsThroughDaylightSavingChanges() {
        let newYork = calendar("America/New_York")
        // Spring forward: Sun 14 Mar 2027. Fall back: Sun 1 Nov 2026.
        for (year, month, startDay, count, todayDay, todayMonth) in [(2027, 3, 10, 7, 16, 3), (2026, 10, 29, 6, 3, 11)] {
            let first = CalendarDay(date: date(month, startDay, year: year, calendar: newYork), calendar: newYork)
            let entries = (0..<count).map { offset -> LoggingStreakEntry in
                let day = first.advanced(byDays: offset)!.startDate.addingTimeInterval(12 * 3600)
                return LoggingStreakEntry(dateLogged: day, createdAt: day)
            }
            let today = CalendarDay(date: date(todayMonth, todayDay, year: year, calendar: newYork), calendar: newYork)

            let summary = LoggingStreakSummary.make(entries: entries, today: today, flexDays: [])

            XCTAssertEqual(summary.current, count, "DST \(year)-\(month)")
            XCTAssertEqual(summary.totalLoggedDays, count)
            XCTAssertEqual(newYork.component(.weekday, from: summary.currentWeek[0].day.startDate), 2, "weeks start on Monday")
        }
    }

    func testTimeZoneChangeRederivesTheSameInstants() {
        // Noon UTC on 20-24 Nov is 01:00 on 21-25 Nov in Auckland: still five contiguous days.
        let entries = (20...24).map { LoggingStreakEntry(dateLogged: date(11, $0), createdAt: date(11, $0)) }
        let utcToday = CalendarDay(date: date(11, 25), calendar: calendar())
        let auckland = calendar("Pacific/Auckland")
        let aucklandToday = CalendarDay(date: date(11, 25), calendar: auckland)

        let inUTC = LoggingStreakSummary.make(entries: entries, today: utcToday, flexDays: [])
        let inAuckland = LoggingStreakSummary.make(entries: entries, today: aucklandToday, flexDays: [])

        XCTAssertEqual(inUTC.current, 5)
        XCTAssertEqual(inAuckland.current, 5)
        XCTAssertEqual(inUTC.lastCountedDay?.sharingDayKey, "2026-11-24")
        XCTAssertEqual(inAuckland.lastCountedDay?.sharingDayKey, "2026-11-25")
    }

    func testBadgesAreEarnedAtExactThresholdsAndNeverLost() {
        XCTAssertEqual(StreakBadge.earned(best: 6, highestEarnedDays: 0), [])
        XCTAssertEqual(StreakBadge.earned(best: 7, highestEarnedDays: 0), [.oneWeek])
        XCTAssertEqual(StreakBadge.earned(best: 89, highestEarnedDays: 0), [.oneWeek, .oneMonth])
        XCTAssertEqual(StreakBadge.earned(best: 365, highestEarnedDays: 0), StreakBadge.allCases)
        // Deleting entries lowers best, but the persisted threshold keeps the badge.
        XCTAssertEqual(StreakBadge.earned(best: 3, highestEarnedDays: 30), [.oneWeek, .oneMonth])
    }

    func testDeletingEntriesLowersBestButTheBadgeStays() {
        let full = summary([16, 17, 18, 19, 20, 21, 22], today: 22)
        XCTAssertEqual(full.best, 7)
        let pruned = summary([16, 17, 18], today: 22)

        XCTAssertEqual(pruned.best, 3)
        XCTAssertEqual(StreakBadge.earned(best: pruned.best, highestEarnedDays: full.best >= 7 ? 7 : 0), [.oneWeek])
    }

    func testBackupCarriesStreakProgressAndOldBackupsStillDecode() throws {
        var settings = BackupSettings.default
        settings.streaks = BackupStreakProgress(flexDays: "2026-11-27", highestBadgeDays: 30, celebratedBadgeDays: 7)
        let decoded = try JSONDecoder().decode(BackupSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded, settings)

        var legacy = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(BackupSettings.default)) as? [String: Any])
        legacy["streaks"] = nil
        let old = try JSONDecoder().decode(BackupSettings.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(old.streaks)
    }

    func testRestoreNeverLowersEarnedBadges() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "streak-restore-\(UUID().uuidString)"))
        defaults.set(90, forKey: AppStorageKeys.streakHighestBadgeDays)
        defaults.set(90, forKey: AppStorageKeys.streakCelebratedBadgeDays)

        BackupStreakProgress(flexDays: "2026-11-27", highestBadgeDays: 30, celebratedBadgeDays: 30).apply(to: defaults)

        XCTAssertEqual(defaults.integer(forKey: AppStorageKeys.streakHighestBadgeDays), 90)
        XCTAssertEqual(defaults.integer(forKey: AppStorageKeys.streakCelebratedBadgeDays), 90)
        XCTAssertEqual(defaults.string(forKey: AppStorageKeys.streakFlexDays), "2026-11-27")
    }

    func testFlexMarksRoundTripReplaceWithinAWeekAndIgnoreJunk() {
        let calendar = calendar()
        let week = summary([]).currentWeek.map(\.day)
        let thursday = week[3]
        let friday = week[4]

        let first = FlexDayMarks.setting(thursday, inWeek: week, stored: "2026-11-16")
        XCTAssertEqual(first, "2026-11-16,2026-11-26")
        let replaced = FlexDayMarks.setting(friday, inWeek: week, stored: first)
        XCTAssertEqual(replaced, "2026-11-16,2026-11-27")
        XCTAssertEqual(FlexDayMarks.setting(nil, inWeek: week, stored: replaced), "2026-11-16")
        XCTAssertEqual(
            FlexDayMarks.days(from: "2026-11-16,junk,2026-13,2026-11-27", calendar: calendar).map(\.sharingDayKey).sorted(),
            ["2026-11-16", "2026-11-27"]
        )
        XCTAssertTrue(FlexDayMarks.days(from: "", calendar: calendar).isEmpty)
    }
}
