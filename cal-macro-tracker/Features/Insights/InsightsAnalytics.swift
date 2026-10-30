import Foundation

extension CalendarDay: Comparable {
    static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        lhs.startDate < rhs.startDate
    }

    static func dateDistance(from start: CalendarDay, through end: CalendarDay) -> Int {
        start.resolvedCalendar.dateComponents([.day], from: start.startDate, to: end.startDate).day ?? 0
    }
}

enum InsightsWeightNotice {
    static func message(latestWeightDate: Date?, today: CalendarDay, dismissedAt: Date?) -> String? {
        // Compare local civil days; future weight entries stay recent during a clock rollback.
        let calendar = today.resolvedCalendar
        let cutoffDate = calendar.date(byAdding: .month, value: -1, to: today.startDate) ?? today.startDate
        let cutoffDay = CalendarDay(date: cutoffDate, calendar: calendar)

        if let latestWeightDate {
            let latestWeightDay = CalendarDay(date: latestWeightDate, calendar: calendar)
            guard latestWeightDay < cutoffDay else { return nil }
        }

        if let dismissedAt, let dismissalInterval = calendar.dateInterval(of: .day, for: dismissedAt) {
            let expiryDate = calendar.date(byAdding: .month, value: 1, to: dismissalInterval.start) ?? dismissalInterval.start
            let expiryDay = CalendarDay(date: expiryDate, calendar: calendar)
            guard today >= expiryDay else { return nil }
        }

        return latestWeightDate == nil ? "No weight logged" : "No weight logged in a month"
    }
}

enum InsightsRange: String, CaseIterable, Identifiable {
    case sevenDays = "sevenDays"
    case fourteenDays = "fourteenDays"
    case thirtyDays = "thirtyDays"
    case ninetyDays = "ninetyDays"
    case oneYear = "oneYear"
    case allTime = "allTime"

    var id: Self { self }

    var dayCount: Int? {
        switch self {
        case .sevenDays: 7
        case .fourteenDays: 14
        case .thirtyDays: 30
        case .ninetyDays: 90
        case .oneYear: 365
        case .allTime: nil
        }
    }

    var title: String {
        switch self {
        case .sevenDays:
            "7D"
        case .fourteenDays:
            "14D"
        case .thirtyDays:
            "30D"
        case .ninetyDays:
            "90D"
        case .oneYear:
            "1Y"
        case .allTime:
            "All"
        }
    }

    func days(endingOn endDay: CalendarDay, startingAt earliestDay: CalendarDay? = nil) -> [CalendarDay] {
        guard let dayCount else {
            guard let earliestDay, earliestDay <= endDay else { return [] }
            return calendarDays(from: earliestDay, through: endDay)
        }

        return (0..<dayCount).compactMap { offset in
            endDay.advanced(byDays: offset - dayCount + 1)
        }
    }

    func previousDays(endingBefore endDay: CalendarDay) -> [CalendarDay] {
        guard let dayCount, let previousEndDay = endDay.advanced(byDays: -dayCount) else { return [] }
        return days(endingOn: previousEndDay)
    }

    private func calendarDays(from startDay: CalendarDay, through endDay: CalendarDay) -> [CalendarDay] {
        var days: [CalendarDay] = []
        var day = startDay
        while day <= endDay {
            days.append(day)
            guard let nextDay = day.advanced(byDays: 1) else { break }
            day = nextDay
        }
        return days
    }
}

struct InsightsChartPoint: Identifiable {
    let day: CalendarDay
    let totals: NutritionSnapshot
    let secondaryTotals: SecondaryNutritionSnapshot
    let loggedDayCount: Int

    var id: CalendarDay { day }
}

enum InsightsChartStyle: String, CaseIterable, Identifiable {
    case bars
    case lines

    var id: Self { self }

    var title: String {
        switch self {
        case .bars:
            "Bars"
        case .lines:
            "Lines"
        }
    }
}

enum InsightsNutrient: CaseIterable, Identifiable {
    case saturatedFat
    case fiber
    case sugars
    case addedSugars
    case sodium
    case cholesterol

    var id: Self { self }

    var title: String {
        switch self {
        case .saturatedFat:
            "Saturated Fat"
        case .fiber:
            "Fiber"
        case .sugars:
            "Sugar"
        case .addedSugars:
            "Added Sugar"
        case .sodium:
            "Sodium"
        case .cholesterol:
            "Cholesterol"
        }
    }

    var shortTitle: String {
        switch self {
        case .saturatedFat:
            "Sat Fat"
        case .addedSugars:
            "Added"
        default:
            title
        }
    }

    var unit: String {
        switch self {
        case .sodium, .cholesterol:
            "mg"
        case .saturatedFat, .fiber, .sugars, .addedSugars:
            "g"
        }
    }

    func value(from snapshot: SecondaryNutritionSnapshot) -> Double? {
        switch self {
        case .saturatedFat:
            snapshot.saturatedFat
        case .fiber:
            snapshot.fiber
        case .sugars:
            snapshot.sugars
        case .addedSugars:
            snapshot.addedSugars
        case .sodium:
            snapshot.sodium
        case .cholesterol:
            snapshot.cholesterol
        }
    }
}

struct InsightsDayPoint: Identifiable {
    let day: CalendarDay
    let snapshot: LogEntryDaySnapshot

    var id: CalendarDay { day }
    var isLogged: Bool { !snapshot.entries.isEmpty }
}

struct InsightsMetricSummary: Hashable {
    let average: Double?
    let previousAverage: Double?
    let loggedDayCount: Int
    let totalDayCount: Int

    var comparisonPercent: Double? {
        guard let average, let previousAverage, previousAverage > 0 else { return nil }
        return ((average - previousAverage) / previousAverage) * 100
    }
}

struct InsightsNutrientSummary: Hashable {
    let average: Double?
    let previousAverage: Double?
    let availableDayCount: Int
    let loggedDayCount: Int
    let totalDayCount: Int

    var comparisonPercent: Double? {
        guard let average, let previousAverage, previousAverage > 0 else { return nil }
        return ((average - previousAverage) / previousAverage) * 100
    }
}

struct InsightsGoalAdherence: Hashable {
    let successfulDays: Int
    let loggedDayCount: Int

    var rate: Double? {
        guard loggedDayCount > 0 else { return nil }
        return Double(successfulDays) / Double(loggedDayCount)
    }
}

enum InsightsAnalytics {
    static func currentStreak(days: [CalendarDay], today: CalendarDay) -> Int {
        let loggedDays = Set(days)
        let calendar = today.resolvedCalendar
        let yesterday = today.advanced(byDays: -1)
        var day = loggedDays.contains(today) ? today : (yesterday ?? today)
        var streak = 0
        while loggedDays.contains(day) {
            streak += 1
            guard let previousDate = calendar.date(byAdding: .day, value: -1, to: day.startDate) else { break }
            day = CalendarDay(date: previousDate, calendar: calendar)
        }
        return streak
    }

    static func points(for entries: [LogEntry], days: [CalendarDay]) -> [InsightsDayPoint] {
        let snapshotsByDay = LogEntryDaySummary.snapshotsByDay(for: entries, matching: days)
        return days.map { day in
            InsightsDayPoint(day: day, snapshot: snapshotsByDay[day] ?? .empty)
        }
    }

    static func chartPoints(for points: [InsightsDayPoint]) -> [InsightsChartPoint] {
        points.filter(\.isLogged).map { point in
            InsightsChartPoint(
                day: point.day,
                totals: point.snapshot.totals,
                secondaryTotals: point.snapshot.secondaryTotals,
                loggedDayCount: 1
            )
        }
    }

    static func metricSummary(
        current: [InsightsDayPoint],
        previous: [InsightsDayPoint],
        value: (NutritionSnapshot) -> Double
    ) -> InsightsMetricSummary {
        InsightsMetricSummary(
            average: averageLoggedValue(in: current, value: value),
            previousAverage: averageLoggedValue(in: previous, value: value),
            loggedDayCount: loggedDayCount(in: current),
            totalDayCount: current.count
        )
    }

    static func nutrientSummary(
        current: [InsightsDayPoint],
        previous: [InsightsDayPoint],
        nutrient: InsightsNutrient
    ) -> InsightsNutrientSummary {
        InsightsNutrientSummary(
            average: averageAvailableNutrient(in: current, nutrient: nutrient),
            previousAverage: averageAvailableNutrient(in: previous, nutrient: nutrient),
            availableDayCount: availableNutrientDayCount(in: current, nutrient: nutrient),
            loggedDayCount: loggedDayCount(in: current),
            totalDayCount: current.count
        )
    }

    static func loggingConsistency(in points: [InsightsDayPoint]) -> Double? {
        guard !points.isEmpty else { return nil }
        return Double(loggedDayCount(in: points)) / Double(points.count)
    }

    static func calorieAdherence(in points: [InsightsDayPoint], calorieGoal: Double) -> InsightsGoalAdherence {
        guard calorieGoal > 0 else {
            return InsightsGoalAdherence(successfulDays: 0, loggedDayCount: loggedDayCount(in: points))
        }

        let lowerBound = calorieGoal * 0.9
        let upperBound = calorieGoal * 1.1
        let loggedPoints = points.filter(\.isLogged)
        let successfulDays = loggedPoints.filter { point in
            let calories = point.snapshot.totals.calories
            return calories >= lowerBound && calories <= upperBound
        }.count

        return InsightsGoalAdherence(successfulDays: successfulDays, loggedDayCount: loggedPoints.count)
    }

    static func proteinAdherence(in points: [InsightsDayPoint], proteinGoal: Double) -> InsightsGoalAdherence {
        guard proteinGoal > 0 else {
            return InsightsGoalAdherence(successfulDays: 0, loggedDayCount: loggedDayCount(in: points))
        }

        let loggedPoints = points.filter(\.isLogged)
        let successfulDays = loggedPoints.filter { $0.snapshot.totals.protein >= proteinGoal }.count
        return InsightsGoalAdherence(successfulDays: successfulDays, loggedDayCount: loggedPoints.count)
    }

    private static func loggedDayCount(in points: [InsightsDayPoint]) -> Int {
        points.filter(\.isLogged).count
    }

    static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func averageLoggedValue(
        in points: [InsightsDayPoint],
        value: (NutritionSnapshot) -> Double
    ) -> Double? {
        let loggedPoints = points.filter(\.isLogged)
        guard !loggedPoints.isEmpty else { return nil }

        let total = loggedPoints.reduce(0) { partial, point in
            partial + value(point.snapshot.totals)
        }
        return total / Double(loggedPoints.count)
    }

    private static func averageAvailableNutrient(
        in points: [InsightsDayPoint],
        nutrient: InsightsNutrient
    ) -> Double? {
        let values = points.compactMap { point in
            nutrient.value(from: point.snapshot.secondaryTotals)
        }
        guard !values.isEmpty else { return nil }

        return values.reduce(0, +) / Double(values.count)
    }

    private static func availableNutrientDayCount(
        in points: [InsightsDayPoint],
        nutrient: InsightsNutrient
    ) -> Int {
        points.compactMap { nutrient.value(from: $0.snapshot.secondaryTotals) }.count
    }
}
