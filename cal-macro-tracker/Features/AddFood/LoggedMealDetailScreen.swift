import SwiftData
import SwiftUI

struct LoggedMealDetailScreen: View {
    @Environment(\.modelContext) private var modelContext

    let entry: LogEntry

    @State private var snapshots: [LoggedMealComponentSnapshot] = []
    @State private var savedMeal: Meal?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Logged Meal") {
                FoodNutritionRow(
                    name: entry.foodName,
                    subtitle: "\(entry.quantitySummary) • \(entry.dateLogged.timeTitle)",
                    calories: entry.caloriesConsumed,
                    protein: entry.proteinConsumed,
                    carbs: entry.carbsConsumed,
                    fat: entry.fatConsumed
                )
            }

            Section("Foods") {
                if snapshots.isEmpty {
                    Text("No component snapshot is available for this logged meal.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshots) { snapshot in
                        FoodNutritionRow(
                            name: snapshot.foodName,
                            subtitle: quantitySummary(for: snapshot),
                            calories: snapshot.caloriesConsumed,
                            protein: snapshot.proteinConsumed,
                            carbs: snapshot.carbsConsumed,
                            fat: snapshot.fatConsumed
                        )
                    }
                }
            }
        }
        .navigationTitle("Meal Details")
        .inlineNavigationTitle()
        .errorBanner(message: $errorMessage)
        .task(id: entry.id) {
            loadDetail()
        }
        .toolbar {
            if let savedMeal {
                ToolbarItem(placement: .appTopBarTrailing) {
                    NavigationLink("Edit Meal") {
                        MealEditorScreen(meal: savedMeal) { _ in
                            loadDetail()
                        } onMealDeleted: {
                            self.savedMeal = nil
                        }
                    }
                }
            }
        }
    }

    private func loadDetail() {
        do {
            snapshots = try componentSnapshots()
            savedMeal = try entry.mealID.flatMap { try MealRepository(modelContext: modelContext).fetchMeal(id: $0) }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func componentSnapshots() throws -> [LoggedMealComponentSnapshot] {
        let entryID = entry.id
        let descriptor = FetchDescriptor<LoggedMealComponentSnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.logEntryID == entryID
            },
            sortBy: [SortDescriptor(\.foodName)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func quantitySummary(for snapshot: LoggedMealComponentSnapshot) -> String {
        snapshot.quantityModeKind.formattedSummary(amount: snapshot.quantityAmount)
    }
}
