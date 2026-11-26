import Foundation

enum ReviewPromptEligibility {
    static func isEligible(
        entryDays: [CalendarDay],
        today: CalendarDay,
        promptedVersion: String,
        lastRequestedAt: Date?,
        appVersion: String,
        now: Date
    ) -> Bool {
        guard !appVersion.isEmpty, promptedVersion != appVersion else { return false }
        guard lastRequestedAt.map({ now.timeIntervalSince($0) >= 14 * 24 * 60 * 60 }) ?? true else { return false }

        let cutoff = today.advanced(byDays: -89) ?? today
        let recentDays = entryDays.filter { $0 >= cutoff && $0 <= today }
        let distinctDays = Set(recentDays)
        let hasBaselineUse = recentDays.count >= 5 && distinctDays.count >= 3
        // A consecutive-day streak is a meaningful engagement moment, not a request for a specific rating.
        // https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews
        let hasPositiveMoment = InsightsAnalytics.currentStreak(days: Array(distinctDays), today: today) >= 3
        return hasBaselineUse || hasPositiveMoment
    }
}
