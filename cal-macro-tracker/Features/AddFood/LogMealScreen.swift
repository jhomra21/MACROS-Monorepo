import SwiftData
import SwiftUI

struct LogMealScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SharingSyncService.self) private var sharingSyncService
    @Environment(\.modelContext) private var modelContext

    let meal: Meal
    let loggingDay: CalendarDay?
    let onMealLogged: () -> Void

    @State private var servingsAmount = 1.0
    @State private var summary: MealNutritionSummary?
    @State private var errorMessage: String?
    @State private var logFeedbackToken = 0
    @State private var editMeal: Meal?

    init(meal: Meal, loggingDay: CalendarDay? = nil, onMealLogged: @escaping () -> Void = {}) {
        self.meal = meal
        self.loggingDay = loggingDay
        self.onMealLogged = onMealLogged
    }

    private var mealRepository: MealRepository {
        MealRepository(modelContext: modelContext)
    }

    private var logEntryRepository: LogEntryRepository {
        LogEntryRepository(modelContext: modelContext, onDailyTotalsChanged: sharingSyncService.syncAfterDailyTotalsChange)
    }

    private var scaledNutrients: LoggedFoodNutrients {
        guard let summary else { return LoggedFoodNutrients.zero }
        return NutritionMath.scaledNutrients(for: summary.nutrients, multiplier: servingsAmount)
    }

    private var canLog: Bool {
        summary != nil
    }

    var body: some View {
        Form {
            Section("Meal") {
                FoodNutritionRow(
                    name: meal.name,
                    subtitle: "\(servingsAmount.roundedForDisplay) meal",
                    calories: scaledNutrients.calories,
                    protein: scaledNutrients.protein,
                    carbs: scaledNutrients.carbs,
                    fat: scaledNutrients.fat
                )
            }

            Section("Quantity") {
                Stepper {
                    LabeledContent("Meals") {
                        Text(servingsAmount.formattedMealServings)
                            .monospacedDigit()
                    }
                } onIncrement: {
                    servingsAmount += 0.5
                } onDecrement: {
                    guard servingsAmount > 0.5 else { return }
                    servingsAmount = max(0.5, servingsAmount - 0.5)
                }
            }

            Section("Foods") {
                if let summary {
                    ForEach(summary.components) { component in
                        FoodNutritionRow(
                            name: component.food.name,
                            subtitle: componentQuantitySummary(component),
                            calories: component.nutrients.calories * servingsAmount,
                            protein: component.nutrients.protein * servingsAmount,
                            carbs: component.nutrients.carbs * servingsAmount,
                            fat: component.nutrients.fat * servingsAmount
                        )
                    }
                } else {
                    HStack {
                        ProgressView()
                        Text("Loading meal…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Log Meal")
        .inlineNavigationTitle()
        .errorBanner(message: $errorMessage)
        .sensoryFeedback(.success, trigger: logFeedbackToken)
        .task(id: meal.id) {
            loadSummary()
        }
        .safeAreaInset(edge: .bottom) {
            BottomPinnedActionBar(title: "Log Meal", systemImage: nil, isDisabled: !canLog) {
                logMeal()
            }
        }
        .toolbar {
            ToolbarItem(placement: .appTopBarTrailing) {
                Button("Edit Meal") {
                    editMeal = meal
                }
            }
        }
        .navigationDestination(item: $editMeal) { meal in
            MealEditorScreen(meal: meal) { savedMeal in
                editMeal = nil
                loadSummary(for: savedMeal)
            } onMealDeleted: {
                editMeal = nil
                dismiss()
            }
        }
    }

    private func loadSummary() {
        loadSummary(for: meal)
    }

    private func loadSummary(for meal: Meal) {
        do {
            summary = try mealRepository.nutritionSummary(for: meal)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func logMeal() {
        do {
            try logEntryRepository.logMeal(
                meal: meal,
                loggedAt: loggingDay?.date(matchingTimeOf: .now) ?? .now,
                servingsAmount: servingsAmount,
                operation: "Log meal"
            )
            errorMessage = nil
            logFeedbackToken += 1
            onMealLogged()
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }

    private func componentQuantitySummary(_ component: MealComponentSummary) -> String {
        let amount = component.quantityAmount * servingsAmount
        return component.quantityMode.formattedSummary(amount: amount)
    }
}

private extension Double {
    var formattedMealServings: String {
        formatted(
            FloatingPointFormatStyle<Double>.number
                .grouping(.never)
                .precision(.fractionLength(0...2))
                .locale(.current)
        )
    }
}
