# Insights Long Ranges Tracker

## Decisions

- Keep 7D, 14D, and 30D and add 90D, 1Y (365 calendar days), and All. All uses the earliest logged day through today and has no previous comparison period. If there are no log entries, All has no days and shows empty-data states.
- All ranges above 7D remain gated by `PaidFeature.nutritionInsights`.
- Use a compact native menu picker for all six ranges so labels remain legible at accessibility text sizes. The free affordance lists every range, marks 7D selected, and opens the existing Pro paywall for locked choices.
- Keep daily points for summaries, streaks, adherence, nutrient coverage, and every chart range. Omit unlogged chart marks while retaining their calendar-day positions on the x-axis. Use a 30-day visible domain for longer ranges; weight stays record-level.
- Query log entries once per range, bounded to the selected period. For All, resolve the earliest date with a minimum-date SwiftData query and use that as the lower bound. Keep aggregation in-process unless simulator measurement reveals a visible stall.

## File plan

- `cal-macro-tracker/Features/Insights/InsightsAnalytics.swift`: range/date math and summaries.
- `cal-macro-tracker/Features/Insights/InsightsChartBucketing.swift`: pure chart bucket selection and aggregation.
- `cal-macro-tracker/Features/Insights/InsightsChartCards.swift` and `InsightsChartComponents.swift`: chart views and shared presentation helpers.
- `cal-macro-tracker/Features/Insights/InsightsScreen.swift`: one bounded query, empty comparisons, responsive range picker, and free locked affordance.
- `cal-macro-tracker/Features/Insights/InsightsWeightCard.swift`: query weight history only in selected range (all history for All).
- `cal-macro-trackerTests/InsightsAnalyticsTests.swift`: failure-mode-first tests for date math and pure chart bucketing.
- `changes-log.md`: concise dated entry.
- `implementation-trackers/insights-long-ranges-tracker.md`: record decisions, failure modes, completion, and QA.

## Failure modes covered before implementation

- Empty selected range, and no entries at all when All is selected.
- One logged day in a bucket.
- DST transitions when advancing days or finding week boundaries.
- Month boundaries and leap day.
- Partial first and last bucket; averages include only logged days.
- Previous 365-day period crossing a year boundary.
- Today advances while the screen remains open (the supplied `today` value remains the range anchor).
- Dynamic Type overflow in the range picker and crowded chart-axis labels.

## Daily-chart fix failure modes (listed before this fix's implementation)

- 90D, 1Y, and All still selecting weekly/monthly averages.
- Seven consecutive logged dates collapsing into fewer chart marks.
- Two logged dates separated by unlogged dates being positioned next to each other.
- Multiple entries on one date failing to retain the existing daily total.
- Missing nutrient values appearing as zero while an explicitly logged zero remains valid.
- Calendar-day positions drifting at leap day, month boundaries, or a DST transition.
- Axis labels or point selection resolving to a different day after changing range.

## Review coverage and fixes

- `testDailyChartBucketsOmitUnloggedDaysButKeepSummaryCoverage` confirms daily chart points omit empty days while day-accurate summary coverage retains them.
- `testWeeklyAndMonthlyChartBucketsOmitRangesWithNoLoggedDays` confirms empty weekly and monthly ranges produce no chart buckets.
- `testAllTimeBucketUsesSixCalendarMonthThreshold` pins the calendar threshold at exactly six months and one day short.
- `testWeeklyChartBucketStartsRespectExplicitFirstWeekday` pins a Gregorian calendar's `firstWeekday` and expected bucket start dates. The DST test also asserts exact starts on both sides of the week boundary.
- The 365-day previous-period test asserts fixed start/end dates across a year boundary; repeated calls with the same anchor assert range stability.
- Daily chart aggregation now filters unlogged days without changing summary inputs. The All threshold uses six calendar months. The weight query includes the seven-day comparison baseline before the range start while chart/trend points remain inside the selected range.
- The chart bucketing, chart views, and shared chart components moved into focused files without changing chart or screen behavior.

## Status

- [x] Decisions, file plan, and failure modes recorded before implementation.
- [x] Daily chart failure modes and regression tests written before implementation; the old implementation failed the 90D/1Y/All and sparse-date assertions.
- [x] Long ranges remain Pro-gated; all nutrition chart ranges now keep distinct daily totals at calendar-day x positions, with a 30-day visible scrolling window for longer ranges.
- [x] Weekly/monthly aggregation types and labels removed. Nutrient marks omit unknown values, chart lines use linear interpolation, and selection resets when the date domain changes.
- [x] Review fixes, file split, and daily chart changes validated with formatting, simulator build, and 23/23 targeted tests.
- [x] 7D simulator evidence shows seven separate daily bars and seven date labels with the isolated 400-day fixture.
- [x] Native E2E on the corrected binary verifies 7D alignment and Oct 27 selection, 90D pan away/back and matching selection, 14D/30D/1Y/All daily layouts, range-change selection reset, calorie Lines mode, and macro/Fiber chart taps. Exact steps, fixture aggregates, binary identity, screenshots, and remaining gaps are recorded in `build/insights-daily-qa-2026-10-28/QA.md`.

## 2026-10-28 Native E2E

- Binary from `a5b0d34b118c50f655d51ceb05f173a744e3ef3f`: SHA-256 `c7cd0351dfbdb33b69b0f69f00a059f31bae2f63bab68d22bb72219d0f860585`, Mach-O UUID `C2765AA1-0AC5-3B7A-9484-421ABFFC74BB`. The Mach-O entitlement payload includes the expected application identifier, app group, and HealthKit entitlement; the previous report calling this a signing blocker was incorrect.
- QA device: owned iPhone 18 Pro / iOS 27.0, UDID `0D20564F-464C-4416-B6D7-7D27EE4922DC`; Device-panel session `t3-5107c549910e28e2f812d9ca`. Fixture preserved: 400 entries/days, `2025-09-23`–`2026-10-27`; totals 438,500 kcal, 21,985 g protein, 25,902 g carbs, 6,400 g fat; fiber present on 300 entries.
- The corrected 7D screenshot shows date ticks `2026-10-22`–`2026-10-28`, with bars on the six logged dates only. Tapping Oct 27 gives 1,400 kcal. 90D swipe changes the visible domain from October dates to late July/August dates; reverse swipe returns to October, where Oct 27 again selects 1,400 kcal. 14D, 30D, 1Y, and All were opened; 1Y and All chart scrolling were exercised. All reached day indices 0–50 and shows dates from September/October 2025. Range change clears selection.
- Calorie Lines, macro Lines, and Fiber Lines render. Macro selection on Oct 27 reads `P 40g • C 51g • F 22g`; Fiber selection reads `18 g`, with All-range coverage `300/400 logged days`. Fiber panning changes the visible domain from day indices 350–400 to 300–350; selecting an earlier visible point reads Aug 12, 6 g. A macro-chart pan attempt navigated back to Dashboard, so long-range macro panning remains unverified. The action log and screenshots are in the ignored QA artifact. Exhaustive nutrient/style/range combinations remain unverified.
