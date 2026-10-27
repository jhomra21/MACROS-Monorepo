import Foundation

extension InsightsAnalytics {
    static func chartBucket(for range: InsightsRange, points: [InsightsDayPoint]) -> InsightsChartBucket {
        switch range {
        case .sevenDays, .fourteenDays, .thirtyDays:
            return .daily
        case .ninetyDays:
            return .weekly
        case .oneYear:
            return .monthly
        case .allTime:
            guard let first = points.first?.day, let last = points.last?.day else { return .weekly }
            let calendar = first.resolvedCalendar
            guard let sixMonthsAfterStart = calendar.date(byAdding: .month, value: 6, to: first.startDate) else {
                return .monthly
            }
            return last.startDate < sixMonthsAfterStart ? .weekly : .monthly
        }
    }

    static func chartPoints(for points: [InsightsDayPoint], bucket: InsightsChartBucket) -> [InsightsChartPoint] {
        guard bucket != .daily else {
            return points.filter(\.isLogged).map { point in
                InsightsChartPoint(
                    day: point.day,
                    totals: point.snapshot.totals,
                    secondaryTotals: point.snapshot.secondaryTotals,
                    loggedDayCount: point.isLogged ? 1 : 0
                )
            }
        }

        let grouped = Dictionary(grouping: points.filter(\.isLogged)) { point in
            ChartBucketKey(day: point.day, bucket: bucket)
        }

        return grouped.map { key, bucketPoints in
            let loggedCount = bucketPoints.count
            let totals = bucketPoints.reduce(into: NutritionSnapshot.zero) { result, point in
                result.calories += point.snapshot.totals.calories
                result.protein += point.snapshot.totals.protein
                result.fat += point.snapshot.totals.fat
                result.carbs += point.snapshot.totals.carbs
            }
            let secondaryTotals = SecondaryNutritionSnapshot(
                saturatedFat: average(bucketPoints.compactMap { $0.snapshot.secondaryTotals.saturatedFat }),
                fiber: average(bucketPoints.compactMap { $0.snapshot.secondaryTotals.fiber }),
                sugars: average(bucketPoints.compactMap { $0.snapshot.secondaryTotals.sugars }),
                addedSugars: average(bucketPoints.compactMap { $0.snapshot.secondaryTotals.addedSugars }),
                sodium: average(bucketPoints.compactMap { $0.snapshot.secondaryTotals.sodium }),
                cholesterol: average(bucketPoints.compactMap { $0.snapshot.secondaryTotals.cholesterol })
            )
            return InsightsChartPoint(
                day: key.startDay,
                totals: NutritionSnapshot(
                    calories: totals.calories / Double(loggedCount),
                    protein: totals.protein / Double(loggedCount),
                    fat: totals.fat / Double(loggedCount),
                    carbs: totals.carbs / Double(loggedCount)
                ),
                secondaryTotals: secondaryTotals,
                loggedDayCount: loggedCount
            )
        }
        .sorted { $0.day < $1.day }
    }

    private struct ChartBucketKey: Hashable {
        let startDay: CalendarDay

        init(day: CalendarDay, bucket: InsightsChartBucket) {
            let calendar = day.resolvedCalendar
            switch bucket {
            case .daily:
                startDay = day
            case .weekly:
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: day.startDate)?.start ?? day.startDate
                startDay = CalendarDay(date: weekStart, calendar: calendar)
            case .monthly:
                var components = calendar.dateComponents([.era, .year, .month], from: day.startDate)
                components.day = 1
                let monthStart = calendar.date(from: components) ?? day.startDate
                startDay = CalendarDay(date: monthStart, calendar: calendar)
            }
        }
    }

}
