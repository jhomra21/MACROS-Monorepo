# Insights Implementation Tracker

Working tracker for the premium nutrition insights feature. Update this file as implementation progresses with task status, bugs, quirks, findings, validation notes, and new decisions.

## Shared Understanding

- Goal: Add a premium Insights screen that gives users deeper analytics for logged calories, macros, and secondary nutrients over rolling time ranges up to one month.
- Premium gate: Insights is included in the existing Full App Unlock purchase, the same entitlement currently used for custom macro ring colors.
- Product intent: This should feel like proper nutrition analytics for fitness-focused users, not just a weekly summary.
- Architecture: Keep implementation native Swift/SwiftUI, feature-focused, local-first, and derived from existing SwiftData `LogEntry` records.
- Data source: Local `LogEntry` data remains authoritative. Insights must not require login, network access, or cloud sync.
- Scope discipline: Keep the first implementation focused and avoid broad refactors or unrelated cleanup.

## Core Decisions

### Scope

- V1 supports fixed rolling ranges only:
  - 7 days
  - 14 days
  - 30 days
- Ranges end on today.
- Historical anchored analytics are out of scope for V1.
- Custom date ranges are out of scope for V1.
- Historical goal versions are out of scope for V1.
- Narrative/generated insight text is out of scope for V1.
- Previous-period chart overlays are out of scope for V1.
- Analytics export/share is out of scope for V1.
- Analytics onboarding/tooltips are out of scope for V1.

### Premium Access

- Add a new paid feature case, likely `PaidFeature.nutritionInsights`, requiring `.fullUnlock`.
- Locked users can open the Insights screen.
- Locked state shows a polished preview with sample/blurred chart cards and an “Unlock Insights” action.
- The unlock action presents `FullUnlockPaywallSheet`.
- Premium gating is validated through the app flow/build for V1, not unit-tested.

### Navigation

- Add an `insights` route to `AppRootView`.
- Add a dashboard toolbar icon entry point for Insights.
- Do not add a dashboard card entry point in V1.

### Data and Aggregation

- Reuse existing daily data paths:
  - `LogEntry`
  - `CalendarDay`
  - `LogEntryQuery`
  - `LogEntryDaySummary`
  - `NutritionSnapshot`
  - `SecondaryNutritionSnapshot`
- Query only the selected current range and the equivalent previous range.
- Do not query full history for V1 analytics.
- Treat a logged day as any day with at least one `LogEntry`.
- Nutrition averages exclude days with no entries.
- Logging consistency is shown separately as `logged days / total days`.
- Previous-period comparisons apply to summary metrics only.
- Previous-period comparison ranges use the same number of days immediately before the selected range.

### Missing Nutrient Data

- Secondary nutrient values must preserve the distinction between missing and zero.
- Secondary nutrient averages exclude days where the selected nutrient is missing.
- Show data coverage, e.g. `Fiber data available on 12/30 logged days`.
- Do not silently treat missing secondary nutrient values as zero.

### Charts

- Use Swift Charts.
- Chart style is configurable per card.
- Calories support:
  - bar chart
  - line chart
- Macros support:
  - default stacked bar chart
  - alternate three-line trend chart for protein, carbs, and fat
- Secondary nutrients support:
  - bar chart
  - line chart
- Charts support tap/drag selection.
- Selected chart points show a compact selected-day value callout.

### Analytics Metrics

- Include charts, averages, previous-period comparisons, data coverage, and goal adherence.
- Include calorie goal adherence using current active goals only.
- “Within calorie target” means within ±10% of the current calorie goal.
- Include protein goal adherence using current active goals only.
- Protein goal success means protein is greater than or equal to the current protein goal.
- Over-goal protein is not penalized.
- Label goal-based analytics clearly so users understand they use current goals, not historical goal versions.

### Animation and Interaction

- Charts animate on first screen/card appearance.
- Range or chart-style changes use subtle value transitions.
- Do not replay dramatic entrance animations on every control change.
- Keep UI animations under roughly 300ms.
- When Reduce Motion is enabled, use opacity-only transitions and avoid bar-growth or line-draw motion.
- Use animation to clarify state, not as decorative noise.

### SwiftUI and Design Guidelines

- Follow MV-style SwiftUI; do not introduce a view model by default.
- Use `@State`, `@Environment`, and `@Query` directly where appropriate.
- Keep state close to where it is used.
- Keep related Insights types in the feature area.
- Start with the smallest clean file structure and split only if needed.
- Prefer pure helper functions/types for analytics math.
- Use existing app styling:
  - `PlatformColors.groupedBackground`
  - `appGlassRoundedRect`
  - `AppTopBarLeadingTitle`
- Use Liquid Glass APIs consistently with existing app patterns.
- Use `GlassEffectContainer` where multiple glass elements sit together.
- Use interactive glass only for tappable controls.
- Avoid custom blur/material hacks.

## Proposed File Shape

Start focused:

- `cal-macro-tracker/Features/Insights/InsightsScreen.swift`
- `cal-macro-tracker/Features/Insights/InsightsAnalytics.swift`

Add more files only if the implementation becomes large enough to justify it.

Potential extracted types:

- `InsightsRange`
- `InsightsChartStyle`
- `InsightsNutrient`
- `InsightsDayPoint`
- `InsightsAnalyticsSummary`
- `InsightsPreviousPeriodComparison`

## Milestones and Tasks

### Milestone 1 — Analytics Contract and Tests

- [x] Add a small test target if feasible.
- [x] Add pure Insights analytics helpers.
- [x] Generate rolling 7D/14D/30D day ranges ending today.
- [x] Build current-period and previous-period summaries.
- [x] Compute logged-day averages excluding no-entry days.
- [x] Compute logging consistency.
- [x] Compute secondary nutrient data coverage.
- [x] Compute calorie target adherence with ±10% tolerance.
- [x] Compute protein goal adherence as `>= current protein goal`.
- [x] Add focused tests for the Insights analytics contract.

### Milestone 2 — Route and Premium Gate

- [x] Add `PaidFeature.nutritionInsights`.
- [x] Add Insights route to `AppRootView`.
- [x] Add dashboard toolbar icon entry point.
- [x] Add placeholder `InsightsScreen`.
- [x] Add locked preview state.
- [x] Present `FullUnlockPaywallSheet` from locked preview.

### Milestone 3 — Calories Analytics Card

- [x] Add range selector.
- [x] Add calories summary metrics.
- [x] Add calories previous-period comparison.
- [x] Add calories bar chart.
- [x] Add calories line chart.
- [x] Add per-card bar/line control.
- [x] Add selected-day interaction/callout.
- [x] Add current-goal target range display.

### Milestone 4 — Macros Analytics Card

- [x] Add macro summary metrics.
- [x] Add macro previous-period comparison where useful.
- [x] Add stacked macro bar chart.
- [x] Add three-line macro trend chart.
- [x] Add per-card chart mode control.
- [x] Add selected-day interaction/callout.
- [x] Add protein goal adherence display.

### Milestone 5 — Secondary Nutrients Analytics Card

- [x] Add nutrient picker.
- [x] Support saturated fat, fiber, sugars, added sugars, sodium, and cholesterol.
- [x] Add nutrient summary metrics.
- [x] Add nutrient previous-period comparison.
- [x] Add nutrient data coverage display.
- [x] Add nutrient bar chart.
- [x] Add nutrient line chart.
- [x] Add selected-day interaction/callout.
- [x] Handle all-missing nutrient state.

### Milestone 6 — Polish and Accessibility

- [x] Add first-appearance chart animation.
- [x] Add subtle range/style value transitions.
- [x] Respect Reduce Motion with opacity-only transitions.
- [x] Verify VoiceOver labels for charts and controls.
- [x] Verify locked preview communicates premium value without exposing user data.
- [x] Review implementation for redundant abstractions or duplicated logic.

### Milestone 7 — Validation and Cleanup

- [x] Run Insights analytics tests.
- [x] Run `make quality-format-check`.
- [x] Run Xcode build.
- [x] Manually verify locked and unlocked Insights flows.
- [x] Manually verify 7D/14D/30D ranges.
- [x] Manually verify chart selection/callouts.
- [x] Run simplify review after implementation.
- [x] Run defensive-code review after validators pass.
- [x] Record quirks/findings in this tracker.

## Edge Cases

- No entries in selected range: show an empty state instead of misleading averages.
- No entries in previous period: show neutral comparison copy instead of `0%` change.
- Future days in current range: do not imply zero intake before the day happens.
- Days with entries but zero nutrients: count as logged days.
- Secondary nutrient missing for a day: exclude from that nutrient average and coverage denominator logic.
- Secondary nutrient explicitly logged as zero: treat as valid zero data.
- Current goals missing or invalid: use existing active/default goal handling.
- Goal comparison uses current active goals only.
- Timezone and DST boundaries must rely on existing `CalendarDay`/`LogEntryQuery` behavior.
- Large local history should not affect Insights because queries are range-scoped.
- Locked users should not need detailed user-data chart computation for the preview.

## Validation Plan

- Add tests for pure analytics calculations only.
- Do not test SwiftUI chart rendering in V1.
- Do not test premium gating in the new test target.
- Validate premium gating manually through the app flow.
- Use the documented project validators:
  - `make quality-format-check`
  - Xcode build for the app target

## Open Questions / Blockers

- None remaining for V1.

## Bugs / Quirks / Findings

- Added a small hosted XCTest target for the Insights analytics contract. The app scheme now includes `cal-macro-trackerTests`.
- The first implementation keeps chart-card local selection state in each card and uses Swift Charts `chartXSelection`.
- Manual simulator verification on iPhone 17 Pro confirmed the dashboard Insights toolbar entry, unlocked Insights content, range picker, chart-style controls, chart accessibility labels, selection interaction, and nutrient all-missing empty state with local test data.
- Simplify review found duplicate calorie goal `RuleMark` rendering in the calories chart; fixed it so the goal rule is emitted once per chart.
- Defensive-code review found no high-confidence redundant defensive guards to remove.

## Validation Notes

- Insights analytics tests: `xcodebuild -project "cal-macro-tracker.xcodeproj" -scheme "cal-macro-tracker" -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test` passed.
- Format check: `make quality-format-check` passed.
- XcodeBuildMCP iOS Simulator build for `cal-macro-tracker` on iPhone 17 Pro passed.
- Final validation after cleanup: `make quality-format-check` passed and the full app scheme test command passed with all 6 `InsightsAnalyticsTests`.
