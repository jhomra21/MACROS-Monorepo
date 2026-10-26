import Foundation

struct WeightAnalyticsPoint {
    let day: Date
    let recordedAt: Date
    let weightKg: Double
}

struct WeightMovingAveragePoint: Identifiable {
    let day: Date
    let averageKg: Double
    var id: Date { day }
}

struct WeightChangeComparison {
    let changeKg: Double
    let baselineDay: Date
}

enum WeightAnalytics {
    static func latest(from points: [WeightAnalyticsPoint]) -> WeightAnalyticsPoint? {
        valid(points).max {
            if $0.day != $1.day { return $0.day < $1.day }
            return $0.recordedAt < $1.recordedAt
        }
    }

    static func movingAverages(
        from points: [WeightAnalyticsPoint],
        calendar: Calendar = .current,
        windowDays: Int = 7
    ) -> [WeightMovingAveragePoint] {
        guard windowDays > 0 else { return [] }
        let byDay = Dictionary(grouping: valid(points)) { calendar.startOfDay(for: $0.day) }
        let daily = byDay.keys.sorted().compactMap { day -> (Date, Double)? in
            guard let latest = byDay[day]?.max(by: { $0.recordedAt < $1.recordedAt }) else { return nil }
            return (day, latest.weightKg)
        }
        var result: [WeightMovingAveragePoint] = []
        var windowStart = 0
        var windowTotal = 0.0
        for index in daily.indices {
            let day = daily[index].0
            let startDay = calendar.date(byAdding: .day, value: 1 - windowDays, to: day) ?? day
            while windowStart < index, daily[windowStart].0 < startDay {
                windowTotal -= daily[windowStart].1
                windowStart += 1
            }
            windowTotal += daily[index].1
            result.append(
                WeightMovingAveragePoint(
                    day: day,
                    averageKg: windowTotal / Double(index - windowStart + 1)
                ))
        }
        return result
    }

    static func weeklyRate(from points: [WeightAnalyticsPoint], calendar: Calendar = .current) -> Double? {
        let daily = movingAverages(from: points, calendar: calendar, windowDays: 1)
        guard let first = daily.first, let last = daily.last, first.day < last.day else { return nil }
        let elapsedDays = calendar.dateComponents([.day], from: first.day, to: last.day).day ?? 0
        guard elapsedDays > 0 else { return nil }
        return (last.averageKg - first.averageKg) * 7 / Double(elapsedDays)
    }

    static func changeFromSevenDaysAgo(
        in points: [WeightAnalyticsPoint],
        endingOn date: Date,
        calendar: Calendar = .current
    ) -> Double? {
        comparisonFromSevenDaysAgo(in: points, endingOn: date, calendar: calendar)?.changeKg
    }

    static func comparisonFromSevenDaysAgo(
        in points: [WeightAnalyticsPoint],
        endingOn date: Date,
        calendar: Calendar = .current
    ) -> WeightChangeComparison? {
        let endingDay = calendar.startOfDay(for: date)
        guard let targetDay = calendar.date(byAdding: .day, value: -7, to: endingDay),
            let latest = latest(from: points.filter({ calendar.startOfDay(for: $0.day) == endingDay }))
        else { return nil }

        guard let prior = Self.latest(from: points.filter { calendar.startOfDay(for: $0.day) == targetDay })
        else { return nil }
        return WeightChangeComparison(
            changeKg: latest.weightKg - prior.weightKg,
            baselineDay: targetDay
        )
    }

    private static func valid(_ points: [WeightAnalyticsPoint]) -> [WeightAnalyticsPoint] {
        points.filter { $0.weightKg.isFinite && $0.weightKg > 0 }
    }
}
