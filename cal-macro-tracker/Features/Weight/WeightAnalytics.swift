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
        return daily.indices.map { index in
            let day = daily[index].0
            let startDay = calendar.date(byAdding: .day, value: 1 - windowDays, to: day) ?? day
            let values = daily[...index]
                .filter { $0.0 >= startDay }
                .map(\.1)
            return WeightMovingAveragePoint(day: day, averageKg: values.reduce(0, +) / Double(values.count))
        }
    }

    static func weeklyRate(from points: [WeightAnalyticsPoint], calendar: Calendar = .current) -> Double? {
        let daily = movingAverages(from: points, calendar: calendar, windowDays: 1)
        guard let first = daily.first, let last = daily.last, first.day < last.day else { return nil }
        let elapsedDays = calendar.dateComponents([.day], from: first.day, to: last.day).day ?? 0
        guard elapsedDays > 0 else { return nil }
        return (last.averageKg - first.averageKg) * 7 / Double(elapsedDays)
    }

    private static func valid(_ points: [WeightAnalyticsPoint]) -> [WeightAnalyticsPoint] {
        points.filter { $0.weightKg.isFinite && $0.weightKg > 0 }
    }
}
