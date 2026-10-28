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
- [ ] Existing 90D screenshots show daily marks in a dense-range chart, but do not conclusively establish that horizontal panning moved the domain; point selection and other ranges remain unverified. See the ignored QA notes for limitations.
