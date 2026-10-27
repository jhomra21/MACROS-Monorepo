# Insights Long Ranges Tracker

## Decisions

- Keep 7D, 14D, and 30D and add 90D, 1Y (365 calendar days), and All. All uses the earliest logged day through today and has no previous comparison period. If there are no log entries, All has no days and shows empty-data states.
- All ranges above 7D remain gated by `PaidFeature.nutritionInsights`.
- Use a compact native menu picker for all six ranges so labels remain legible at accessibility text sizes. The free affordance lists every range, marks 7D selected, and opens the existing Pro paywall for locked choices.
- Keep daily points for summaries, streaks, adherence, and nutrient coverage. Aggregate chart-only values by average over logged days: daily through 30D, weekly for 90D, monthly for 1Y, and weekly for All under six months, otherwise monthly. Omit buckets with no logged days. Weight stays record-level.
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
- [x] Pure date and bucketing tests written before implementation; five additional review tests bring InsightsAnalyticsTests to 21 tests.
- [x] Long ranges, chart bucketing, picker, and weight range implemented.
- [x] Review fixes and file split validated with format, build, and 21/21 targeted tests.
- [ ] Review-specific seeded UI screenshots for weight comparison, omitted daily gaps, and All threshold were not captured; simulator QA remains documented in `build/insights-qa-2026-10-26/QA.md`.
- [x] Scoped commits created and branch pushed.
