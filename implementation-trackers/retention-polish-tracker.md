# Retention and Polish Tracker (WS7)

## Follow-ups from WS1 review

- Treat USDA-proxy `429` as non-retryable in the iOS barcode client, show “Too many lookups, try again in a minute” (using `Retry-After` when present), and stop the immediate retry.

Status: WS7 implementation and code validation complete on `launch/ws7-retention-polish`; barcode 429 simulator E2E remains unverified because the simulator camera feed is blank.

Branch `launch/ws7-retention-polish`. Mac only. Phase 2: starts after WS2 and WS4 are merged. Read `AGENTS.md`, `swift-dev.mdc`, `Features/Dashboard/DashboardScreen.swift`, `Features/Dashboard/DailyShareCardView.swift`, `Features/Onboarding/*`, `cal_macro_trackerApp.swift`, `Features/Insights/InsightsAnalytics.swift` (consistency helpers), and `implementation-trackers/launch-program-tracker.md`. Activate `swiftui-liquid-glass` and `apple-design` skills if available.

## Core Decisions

- Brand constant: add `App/AppBrand.swift` with `static let displayName` read from `Bundle.main` `CFBundleDisplayName` (fallback "MACROS"). Replace in-code literals: onboarding header, launch accessibility label in `cal_macro_trackerApp.swift`, share card branding in `DailyShareCardView.swift`, paywall title, Settings copy. Plist values stay until the marketing name is final.
- Logging streak: `InsightsAnalytics` already computes logged-day consistency; expose `currentStreak(days:)` (consecutive days ending today or yesterday with at least one entry). Dashboard shows a small secondary-text line under the macro legend, "5-day logging streak", hidden when the streak is 0 or 1. Tapping opens Insights. No glass; it is content, not a control.
- App Store review prompt: `@Environment(\.requestReview)` triggered once per app version after the third distinct logged day and at least five entries, only after a successful log save and never on the paywall. Keys in `AppStorageKeys`.
- Paywall entry audit for the surfaces that exist in this pass: Insights lock and Settings ring-colors row open `ProPaywallSheet` with the appropriate contexts and consistent brand-based copy.
- Website screenshots: none here (WS8 and WS10 own assets).

## Proposed File Shape

- `App/AppBrand.swift`, `App/AppStorageKeys.swift`, `Features/Dashboard/DashboardScreen.swift` (streak line), `Features/Insights/InsightsAnalytics.swift` (streak), `cal_macro_trackerApp.swift` (review trigger wiring in the existing log-save path, likely `LogEntryRepository` notification), small copy edits.
- Tests: extend `InsightsAnalyticsTests` with streak cases (failure list first: no entries, gap yesterday, entry only yesterday, time zone boundary).

## Validation

- Format, build, targeted tests, `git diff --check`; E2E: streak appears after three consecutive days of entries (adjust simulator date), review prompt request observed in console (StoreKit logs the request in debug), all paywall entry points open the sheet; `build/ws7-qa-<date>/QA.md`. Changes-log entry.
- Recorded simulator evidence and the barcode-camera limitation in `build/ws7-qa-2026-10-25/QA.md`.

## Close-out (deferred until WS4, WS5, and WS6 merge)

- [x] Checked the WS4 “Search online for …” prompt against the pinned glass action bar with an empty query, local results, no local results, and the keyboard up. The prompt and pinned actions remain visible and do not collide; no spacing or safe-area change was needed.
- [x] Audited the Insights, weight trends, Health weight import, Backup, reminders, ring colors, and Pro Settings entry points. Contexts match their features; locked Health, Backup, reminders, and ring-color rows use `lock.fill`; included-feature copy uses `AppBrand.displayName`.
- [x] Fixed Pro plan-row wrapping at the largest accessibility text size by stacking row content. The plan names and price/status now use the full row width.
- [x] Confirmed free and Debug Pro states, and opened/dismissed the visible paywalls. Purchase products are unavailable in this simulator; purchase completion remains covered by the existing StoreKit limitation.
- [x] Recorded screenshots and the pass/fail audit table in `build/ws7-qa-2026-10-26/closeout/QA.md`.
- [x] Recorded the remaining simulator limitation: barcode lookup `429` camera handling must be verified on a TestFlight device (non-retryable response and `Retry-After` feedback); see [TestFlight Release Tracker](testflight-release-tracker.md#carried-over-verification-items-must-pass-on-the-testflight-device).
