# Insights Long Ranges Tracker

## Decisions

- Keep 7D, 14D, and 30D and add 90D, 1Y (365 calendar days), and All. All uses the earliest logged day through today and has no previous comparison period. If there are no log entries, All has no days and shows empty-data states.
- All ranges above 7D remain gated by `PaidFeature.nutritionInsights`.
- Use a compact native menu picker for all six ranges so labels remain legible at accessibility text sizes. The free affordance lists every range, marks 7D selected, and opens the existing Pro paywall for locked choices.
- Keep daily points for summaries, streaks, adherence, and nutrient coverage. Aggregate chart-only values by average over logged days: daily through 30D, weekly for 90D, monthly for 1Y, and weekly for All under six months, otherwise monthly. Omit buckets with no logged days. Weight stays record-level.
- Query log entries once per range, bounded to the selected period. For All, resolve the earliest date with a minimum-date SwiftData query and use that as the lower bound. Keep aggregation in-process unless simulator measurement reveals a visible stall.

## File plan

- `cal-macro-tracker/Features/Insights/InsightsAnalytics.swift`: range/date math, bucket selection, and pure chart aggregation.
- `cal-macro-tracker/Features/Insights/InsightsScreen.swift`: one bounded query, chart data and labels, empty comparisons, responsive range picker and free locked affordance.
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

## Status

- [x] Decisions, file plan, and failure modes recorded before implementation.
- [ ] Pure date and bucketing tests written before implementation.
- [ ] Long ranges, chart bucketing, picker, and weight range implemented.
- [ ] Format, build, targeted tests, and simulator QA recorded.
- [ ] Scoped commits created and branch pushed.
