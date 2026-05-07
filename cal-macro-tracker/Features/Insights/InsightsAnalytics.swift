import Foundation

enum InsightsRange: Int, CaseIterable, Identifiable {
    case sevenDays = 7
    case fourteenDays = 14
    case thirtyDays = 30

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sevenDays:
            "7D"
        case .fourteenDays:
            "14D"
        case .thirtyDays:
            "30D"
        }
    }

    func days(endingOn endDay: CalendarDay) -> [CalendarDay] {
        (0..<rawValue).compactMap { offset in
            endDay.advanced(byDays: offset - rawValue + 1)
        }
    }

    func previousDays(endingBefore endDay: CalendarDay) -> [CalendarDay] {
        guard let previousEndDay = endDay.advanced(byDays: -rawValue) else { return [] }
        return days(endingOn: previousEndDay)
    }
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
    static func points(for entries: [LogEntry], days: [CalendarDay]) -> [InsightsDayPoint] {
        let snapshotsByDay = LogEntryDaySummary.snapshotsByDay(for: entries, matching: days)
        return days.map { day in
            InsightsDayPoint(day: day, snapshot: snapshotsByDay[day] ?? .empty)
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
