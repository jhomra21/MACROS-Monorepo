import Foundation
import SwiftData

extension LogEntryRepository {
    func logMeal(
        meal: Meal,
        loggedAt: Date = .now,
        servingsAmount: Double,
        operation: String
    ) throws {
        guard servingsAmount.isFinite, servingsAmount > 0 else {
            throw FoodDraftValidationError.invalidQuantity
        }

        let mealID = meal.id

        try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            let mealRepository = MealRepository(modelContext: isolatedContext)
            guard let isolatedMeal = try mealRepository.fetchMeal(id: mealID) else {
                throw NSError(
                    domain: "LogEntryRepository",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to load meal for logging."]
                )
            }

            let summary = try mealRepository.nutritionSummary(for: isolatedMeal)
            let consumedNutrients = NutritionMath.scaledNutrients(for: summary.nutrients, multiplier: servingsAmount)
            let entryID = UUID()
            let entry = LogEntry(
                id: entryID,
                mealID: isolatedMeal.id,
                dateLogged: loggedAt,
                foodName: isolatedMeal.name,
                brand: nil,
                source: .custom,
                servingDescription: "1 meal",
                gramsPerServing: nil,
                caloriesPerServing: summary.nutrients.calories,
                proteinPerServing: summary.nutrients.protein,
                fatPerServing: summary.nutrients.fat,
                carbsPerServing: summary.nutrients.carbs,
                saturatedFatPerServing: summary.nutrients.saturatedFat,
                fiberPerServing: summary.nutrients.fiber,
                sugarsPerServing: summary.nutrients.sugars,
                addedSugarsPerServing: summary.nutrients.addedSugars,
                sodiumPerServing: summary.nutrients.sodium,
                cholesterolPerServing: summary.nutrients.cholesterol,
                quantityMode: .servings,
                servingsConsumed: servingsAmount,
                caloriesConsumed: consumedNutrients.calories,
                proteinConsumed: consumedNutrients.protein,
                fatConsumed: consumedNutrients.fat,
                carbsConsumed: consumedNutrients.carbs,
                saturatedFatConsumed: consumedNutrients.saturatedFat,
                fiberConsumed: consumedNutrients.fiber,
                sugarsConsumed: consumedNutrients.sugars,
                addedSugarsConsumed: consumedNutrients.addedSugars,
                sodiumConsumed: consumedNutrients.sodium,
                cholesterolConsumed: consumedNutrients.cholesterol,
                secondaryNutrientBackfillState: .current
            )
            isolatedContext.insert(entry)

            for component in summary.components {
                let snapshotNutrients = NutritionMath.scaledNutrients(for: component.nutrients, multiplier: servingsAmount)
                isolatedContext.insert(
                    LoggedMealComponentSnapshot(
                        logEntryID: entryID,
                        mealID: isolatedMeal.id,
                        foodItemID: component.food.id,
                        foodName: component.food.name,
                        quantityMode: component.quantityMode,
                        quantityAmount: component.quantityAmount * servingsAmount,
                        caloriesConsumed: snapshotNutrients.calories,
                        proteinConsumed: snapshotNutrients.protein,
                        fatConsumed: snapshotNutrients.fat,
                        carbsConsumed: snapshotNutrients.carbs,
                        saturatedFatConsumed: snapshotNutrients.saturatedFat,
                        fiberConsumed: snapshotNutrients.fiber,
                        sugarsConsumed: snapshotNutrients.sugars,
                        addedSugarsConsumed: snapshotNutrients.addedSugars,
                        sodiumConsumed: snapshotNutrients.sodium,
                        cholesterolConsumed: snapshotNutrients.cholesterol
                    )
                )
            }
        }

        WidgetTimelineReloader.reloadMacroWidgets()
        onDailyTotalsChanged?(modelContext.container)
    }
}
