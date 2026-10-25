# Retention and Polish Tracker (WS7)

Branch `launch/ws7-retention-polish`. Mac only. Phase 2: starts after WS2 and WS4 are merged. Read `AGENTS.md`, `swift-dev.mdc`, `Features/Dashboard/DashboardScreen.swift`, `Features/Dashboard/DailyShareCardView.swift`, `Features/Onboarding/*`, `cal_macro_trackerApp.swift`, `Features/Insights/InsightsAnalytics.swift` (consistency helpers), and `implementation-trackers/launch-program-tracker.md`. Activate `swiftui-liquid-glass` and `apple-design` skills if available.

## Core Decisions

- Brand constant: add `App/AppBrand.swift` with `static let displayName` read from `Bundle.main` `CFBundleDisplayName` (fallback "MACROS"). Replace in-code literals: onboarding header, launch accessibility label in `cal_macro_trackerApp.swift`, share card branding in `DailyShareCardView.swift`, paywall title, Settings copy. Plist values stay until the marketing name is final.
- Logging streak: `InsightsAnalytics` already computes logged-day consistency; expose `currentStreak(days:)` (consecutive days ending today or yesterday with at least one entry). Dashboard shows a small secondary-text line under the macro legend, "5-day logging streak", hidden when the streak is 0 or 1. Tapping opens Insights. No glass; it is content, not a control.
- App Store review prompt: `@Environment(\.requestReview)` triggered once per app version after the third distinct logged day and at least five entries, only after a successful log save and never on the paywall. Keys in `AppStorageKeys`.
- Paywall entry audit: every Pro surface (Insights lock, ring colors row, weight trend card, Health section, Backup section, reminders) opens `ProPaywallSheet` with the right context and consistent copy ("Included with MACROS Pro"). Fix inconsistencies found.
- Add Food: confirm the WS4 "Search online for …" row renders with the glass action bar states; adjust spacing if they collide.
- Website screenshots: none here (WS8 and WS10 own assets).

## Proposed File Shape

- `App/AppBrand.swift`, `App/AppStorageKeys.swift`, `Features/Dashboard/DashboardScreen.swift` (streak line), `Features/Insights/InsightsAnalytics.swift` (streak), `cal_macro_trackerApp.swift` (review trigger wiring in the existing log-save path, likely `LogEntryRepository` notification), small copy edits.
- Tests: extend `InsightsAnalyticsTests` with streak cases (failure list first: no entries, gap yesterday, entry only yesterday, time zone boundary).

## Validation

- Format, build, targeted tests, `git diff --check`; E2E: streak appears after three consecutive days of entries (adjust simulator date), review prompt request observed in console (StoreKit logs the request in debug), all paywall entry points open the sheet; `build/ws7-qa-<date>/QA.md`. Changes-log entry.
