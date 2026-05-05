import SwiftUI

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        FoodNutritionRow(
            name: entry.foodName,
            subtitle: "\(entry.quantitySummary) • \(entry.dateLogged.timeTitle)",
            calories: entry.caloriesConsumed,
            protein: entry.proteinConsumed,
            carbs: entry.carbsConsumed,
            fat: entry.fatConsumed
        )
    }
}
