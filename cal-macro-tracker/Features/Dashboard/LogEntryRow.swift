import SwiftUI

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        FoodNutritionRow(
            name: entry.foodName,
            subtitle: subtitle,
            calories: entry.caloriesConsumed,
            protein: entry.proteinConsumed,
            carbs: entry.carbsConsumed,
            fat: entry.fatConsumed
        )
        .accessibilityLabel(accessibilityLabel)
    }

    private var subtitle: String {
        let prefix = entry.isMealLog ? "Meal • " : ""
        return "\(prefix)\(entry.quantitySummary) • \(entry.dateLogged.timeTitle)"
    }

    private var accessibilityLabel: String {
        let kind = entry.isMealLog ? "Meal" : "Food"
        return "\(kind), \(entry.foodName), \(entry.quantitySummary), \(entry.dateLogged.timeTitle)"
    }
}
