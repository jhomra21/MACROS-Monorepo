# Weight Log, Apple Health, and Reminders Tracker (WS5)

Branch `launch/ws5-weight-health-reminders`. Mac only. Phase 2: starts after WS2 (Pro entitlements, `PaidFeature.weightTrends`, `.healthWeightImport`, `.multipleReminders`) and WS3 (`BodyProfile`) are merged into `main`. Read `AGENTS.md`, `swift-dev.mdc`, the WS2 and WS3 trackers, `Features/Insights/InsightsScreen.swift` and `InsightsAnalytics.swift`, `Data/Services/LogEntryRepository*.swift` (post-mutation notification used by sharing sync), `App/HomeScreenQuickActionSupport.swift`, `Shared/AppOpenRequest.swift`, and `implementation-trackers/launch-program-tracker.md`. Activate `swift-concurrency-expert`, `swiftui-liquid-glass`, and `write-swift` skills if available.

## Shared Understanding

- The app has no weight tracking, no HealthKit, and no notifications. `BodyProfile.weightKg` (WS3) holds the latest weight used by the calculator. Post-mutation hooks already exist for log entries (used by `SharingSyncService`); Health writes attach to the same hooks.
- Free: basic weight entry, one daily reminder, and writing nutrition to Apple Health. Pro: weight trend charts, weight import from Apple Health, multiple or smart reminders.

## Core Decisions

### Weight log

- `@Model final class WeightEntry`: `id`, `day: String` (calendar day key, same convention as sharing snapshots), `recordedAt: Date`, `weightKg: Double`, `sourceRaw: String` (`manual`, `healthKit`), `healthKitUUID: String?`, `createdAt`, `updatedAt`. One entry per day per source; a manual entry for a day replaces the previous manual entry. Register in both container factories.
- `WeightRepository`: `entries(in:)`, `upsertManual(weightKg:day:)`, `delete(_:)`, `latest()`, and `applyHealthSamples(_:)` with dedupe by `healthKitUUID`. Saving a manual entry also updates `BodyProfile.weightKg`.
- UI: `Features/Weight/WeightScreen.swift` reachable from Settings ("Weight") and from the Insights weight card. List grouped by week with swipe-to-delete, "Log weight" pinned action (`BottomPinnedActionBar`) presenting a compact entry sheet with a numeric field in the profile's unit system and a date (default today). Free.
- Insights weight card (`InsightsWeightCard` in `Features/Insights/`): free state shows latest weight and change versus 7 days ago; Pro state (`PaidFeatureGate(.weightTrends)`) adds a Swift Charts line of daily weights with a 7-day moving average and a weekly rate label for the selected range, matching the existing card style and Reduce Motion handling. Locked state uses the same blurred-real-data pattern as WS2's Insights lock with a CTA to `ProPaywallSheet(context: .weightTrends)`.
- Pure analytics in `Features/Weight/WeightAnalytics.swift` (moving average, weekly rate, missing-day handling); failure list first, then `WeightAnalyticsTests`.

### Apple Health (nutrition write free; weight import Pro)

- Entitlement `com.apple.developer.healthkit` in `cal-macro-tracker.entitlements`; `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` in `Info-iOS.plist`; the Xcode target capability. Note for the owner: the App ID capability must exist in the developer portal (automatic signing adds it).
- `Features/Health/HealthKitService.swift` (`@MainActor @Observable`, HealthKit calls on background tasks): `isAvailable`, `authorizationStatus`, `requestAuthorization()`, `writeNutrition(for entry:)`, `deleteNutrition(for entryID:)`, `backfill(days: 30)`, `startWeightObservation()`.
- Write types: dietaryEnergyConsumed, dietaryProtein, dietaryCarbohydrates, dietaryFatTotal, dietaryFatSaturated, dietaryFiber, dietarySugar, dietarySodium, dietaryCholesterol. Each sample carries a per-entry/type `HKMetadataKeySyncIdentifier` and a strictly incrementing persisted `healthSyncVersion` as `HKMetadataKeySyncVersion` so edits replace in place; deletions remove by sync identifier. Nil nutrients write no sample.
- Read (Pro, gated by `PaidFeature.healthWeightImport`): `HKAnchoredObjectQuery` on bodyMass with a persisted anchor; new samples become `WeightEntry(source: .healthKit)`.
- Hook: subscribe to the existing post-mutation notification in `LogEntryRepository` (same seam sharing uses) so Health writes never block local persistence and run when the "Write nutrition to Health" toggle is on. Writes are free and skip the entitlement check; only weight import checks `canUse(.healthWeightImport)`.
- Settings section "Apple Health" (new file `Features/Health/HealthSettingsSection.swift`): toggles "Write nutrition to Health" (free) and "Read weight from Health" (Pro, gated by `.healthWeightImport`), status line, "Sync last 30 days" button (nutrition backfill, free), and a locked row on the "Read weight from Health" toggle opening `ProPaywallSheet(context: .healthWeightImport)` when not Pro. Denied authorization shows guidance to open the Health app's Sources settings.

### Reminders

- `Features/Reminders/ReminderScheduler.swift` using `UNUserNotificationCenter`: free users get one daily reminder (default 8:00 PM, "Log today's meals"). Scheduling is deterministic: maintain non-repeating calendar-trigger requests for the next 7 days, skipping days that already have at least one `LogEntry`; recompute on app active and after log mutations. Identifiers `reminder.daily.<day>`.
- Pro (`PaidFeature.multipleReminders`): up to three named reminders (for example Breakfast, Lunch, Dinner) plus an optional "evening check-in only if nothing logged" variant. Same skip logic per reminder.
- Tapping a notification opens Add Food through the existing `AppOpenRequest.addFood(.addFood)` path; implement `UNUserNotificationCenterDelegate` in the existing `HomeScreenQuickActionAppDelegate` to route it. Set the delegate at launch.
- Settings section "Reminders" (`Features/Reminders/ReminderSettingsSection.swift`): authorization handling (request on first enable; denied state links to app settings), time pickers, Pro rows gated.
- Persist reminder configuration in `AppStorage` keys added to `AppStorageKeys`.

## Proposed File Shape

- `Data/Models/WeightEntry.swift`, `Data/Services/WeightRepository.swift`, container registration edits.
- `Features/Weight/{WeightScreen,WeightEntrySheet,WeightAnalytics}.swift`, `Features/Insights/InsightsWeightCard.swift` (+ one insertion in `InsightsScreen.swift`).
- `Features/Health/{HealthKitService,HealthSettingsSection}.swift`.
- `Features/Reminders/{ReminderScheduler,ReminderSettingsSection}.swift`, `App/HomeScreenQuickActionSupport.swift` (delegate), `cal_macro_trackerApp.swift` (start scheduler and Health observation), `App/AppStorageKeys.swift`.
- `Features/Settings/SettingsScreen.swift`: three section insertions only.
- Tests: `WeightAnalyticsTests`, `ReminderSchedulerTests` (pure day-selection logic), `MealSchemaMigrationTests` store-open check for the new model.

## Milestones and Tasks

1. Failure lists and tests for weight analytics and reminder day selection.
2. Weight model, repository, screen, Insights card.
3. HealthKit entitlement, service, hooks, settings.
4. Reminders scheduler, delegate routing, settings.
5. Validation: format, build, targeted tests, `git diff --check`; E2E in a simulator with the Health app: log a food and confirm Dietary Energy appears in Health; add a weight in Health and confirm it appears in the app; schedule a reminder, verify pending requests, and tap it from the simulator notification; all screenshots and steps in `build/ws5-qa-<date>/QA.md`. Changes-log entry.

### Failure modes (2026-10-25, before tests)

Weight analytics:
- Empty history returns no latest value or trend.
- Out-of-order and duplicate-day entries resolve deterministically to the latest recorded sample.
- Seven-day moving averages include available observations without inventing values for missing days.
- Weekly rate compares endpoints using elapsed calendar days and handles missing endpoints or insufficient dates.
- Non-finite and non-positive weights do not contaminate calculations.

Reminder day selection:
- Logged days are skipped in the app calendar/time zone.
- Missing days are selected in chronological order through the requested horizon.
- A day with any log is skipped even when multiple reminders are configured.
- Day boundaries and DST changes use calendar addition rather than fixed 24-hour intervals.
- A zero-length horizon produces no dates.

## Edge Cases

- Health authorization is per type; partially granted sets must still work.
- Backfill must not duplicate samples (sync identifier) and must be cancellable.
- Reminder skip logic uses the app's `AppDayContext` calendar and time zone.

## Status (2026-10-25)

- Implementation and focused validation are in place. Formatting and app build pass; the original 32-test selection and an 8-test selection after review fixes pass.
- Simulator QA verified onboarding, manual weight persistence, the free Insights weight card and locked Pro trend state, a food log, and the daily-reminder permission/setup UI. Health sample write/readback and delivered-notification interaction were not verified; see `build/ws5-qa-2026-10-25/QA.md`.
