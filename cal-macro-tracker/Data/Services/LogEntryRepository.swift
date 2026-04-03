import Foundation
import SwiftData

@MainActor
struct LogEntryRepository {
    let modelContext: ModelContext

    func saveEdits(entry: LogEntry, draft: FoodDraft, quantityMode: QuantityMode, quantityAmount: Double, operation: String) throws {
        let normalizedDraft = draft.normalized()
        if let validationError = normalizedDraft.validationErrorForLogging(quantityMode: quantityMode, quantityAmount: quantityAmount) {
            throw validationError
        }

        let entryID = entry.persistentModelID

        try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            guard let isolatedEntry = isolatedContext.model(for: entryID) as? LogEntry else {
                throw NSError(domain: "LogEntryRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load log entry for saving."])
            }

            apply(
                draft: normalizedDraft,
                quantityMode: quantityMode,
                quantityAmount: quantityAmount,
                to: isolatedEntry
            )
        }
    }

    func delete(entry: LogEntry, operation: String) throws {
        let entryID = entry.persistentModelID

        try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            guard let isolatedEntry = isolatedContext.model(for: entryID) as? LogEntry else {
                throw NSError(domain: "LogEntryRepository", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to load log entry for deletion."])
            }

            isolatedContext.delete(isolatedEntry)
        }
    }

    func logFood(
        draft: FoodDraft,
        shouldSaveCustomFood: Bool,
        logDate: Date,
        quantityMode: QuantityMode,
        quantityAmount: Double,
        operation: String
    ) throws {
        let normalizedDraft = draft.normalized()
        if let validationError = normalizedDraft.validationErrorForLogging(quantityMode: quantityMode, quantityAmount: quantityAmount) {
            throw validationError
        }

        try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            let foodRepository = FoodItemRepository(modelContext: isolatedContext)
            let storedFood = shouldSaveCustomFood ? try foodRepository.upsertReusableCustomFood(from: normalizedDraft, in: isolatedContext) : nil
            let entry = makeLogEntry(
                draft: normalizedDraft,
                storedFood: storedFood,
                shouldSaveCustomFood: shouldSaveCustomFood,
                logDate: logDate,
                quantityMode: quantityMode,
                quantityAmount: quantityAmount
            )

            isolatedContext.insert(entry)
        }
    }

    private func apply(draft: FoodDraft, quantityMode: QuantityMode, quantityAmount: Double, to entry: LogEntry) {
        let consumedNutrition = NutritionMath.consumedNutrition(for: draft, mode: quantityMode, amount: quantityAmount)

        entry.foodName = draft.name
        entry.brand = draft.brandOrNil
        entry.servingDescription = draft.servingDescription
        entry.gramsPerServing = draft.gramsPerServing
        entry.caloriesPerServing = draft.caloriesPerServing
        entry.proteinPerServing = draft.proteinPerServing
        entry.fatPerServing = draft.fatPerServing
        entry.carbsPerServing = draft.carbsPerServing
        entry.quantityMode = quantityMode.rawValue
        entry.servingsConsumed = quantityMode == .servings ? quantityAmount : nil
        entry.gramsConsumed = quantityMode == .grams ? quantityAmount : nil
        entry.caloriesConsumed = consumedNutrition.calories
        entry.proteinConsumed = consumedNutrition.protein
        entry.fatConsumed = consumedNutrition.fat
        entry.carbsConsumed = consumedNutrition.carbs
        entry.updatedAt = .now
    }

    private func makeLogEntry(
        draft: FoodDraft,
        storedFood: FoodItem?,
        shouldSaveCustomFood: Bool,
        logDate: Date,
        quantityMode: QuantityMode,
        quantityAmount: Double
    ) -> LogEntry {
        let consumedNutrition = NutritionMath.consumedNutrition(for: draft, mode: quantityMode, amount: quantityAmount)

        return LogEntry(
            dateLogged: logDate,
            foodName: storedFood?.name ?? draft.name,
            brand: storedFood?.brand ?? draft.brandOrNil,
            source: storedFood?.sourceKind ?? (shouldSaveCustomFood ? .custom : draft.source),
            servingDescription: storedFood?.servingDescription ?? draft.servingDescription,
            gramsPerServing: storedFood?.gramsPerServing ?? draft.gramsPerServing,
            caloriesPerServing: storedFood?.caloriesPerServing ?? draft.caloriesPerServing,
            proteinPerServing: storedFood?.proteinPerServing ?? draft.proteinPerServing,
            fatPerServing: storedFood?.fatPerServing ?? draft.fatPerServing,
            carbsPerServing: storedFood?.carbsPerServing ?? draft.carbsPerServing,
            quantityMode: quantityMode,
            servingsConsumed: quantityMode == .servings ? quantityAmount : nil,
            gramsConsumed: quantityMode == .grams ? quantityAmount : nil,
            caloriesConsumed: consumedNutrition.calories,
            proteinConsumed: consumedNutrition.protein,
            fatConsumed: consumedNutrition.fat,
            carbsConsumed: consumedNutrition.carbs
        )
    }
}
