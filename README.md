# Streak milestones, phase 1 (2026-11-25)

Branch: `feature/streak-milestones` (from `integration/onboarding-preview` 343aaf16). Not merged.

## Choices
- **Flex day:** bridges the streak without adding to it. If the user logged on the flex day anyway, that day counts like any logged day (+1). One per Monday-Sunday week (fixed Monday, local zone). A marked day wins; otherwise the first settled miss is used. Yesterday and today are never missed (48 hours).
- **Old `createdAt`:** `LogEntry.createdAt` is non-optional, set at creation and preserved by backup export/import, so restored history keeps its real timing and nothing is guessed. Entries edited to an earlier date keep their old `createdAt`, so they do not count (no backfill by editing).
- **Existing long streaks:** the first log after update shows one celebration for the highest badge already earned.
- Flex marks, highest earned and celebrated badge are UserDefaults keys, included in backups (a restore never lowers badges).

## Validation
- Build and swift-format pass.
- 20 streak-rule checks (63 assertions) pass in a macOS harness compiling the same `LoggingStreakSummary.swift` and test source. The XCTest run and the E2E screenshots did **not** happen: iPhone Air ("Data Migration Failed") and iPhone 17e stayed on the Apple logo with SpringBoard frozen, and iPhone 17 was held by another task. Both devices I booted were shut down and their locks released.
- The two images are SwiftUI `ImageRenderer` renders of `StreakMedallionView` on macOS (light and dark), **not** simulator screenshots.
