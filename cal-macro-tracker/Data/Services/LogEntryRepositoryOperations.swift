import Foundation
import SwiftData

extension LogEntryRepository {
    func saveEdits(
        entry: LogEntry,
        draft: FoodDraft,
        quantityMode: QuantityMode,
        quantityAmount: Double,
        operation: String
    ) throws {
        let normalizedDraft = draft.normalized()
        if let validationError = normalizedDraft.validationErrorForLogging(
            quantityMode: quantityMode,
            quantityAmount: quantityAmount
        ) {
            throw validationError
        }

        let entryID = entry.persistentModelID

        try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            guard let isolatedEntry = isolatedContext.model(for: entryID) as? LogEntry else {
                throw NSError(
                    domain: "LogEntryRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load log entry for saving."])
            }

            let editedEntryResolution = resolvedEditedEntry(
                from: normalizedDraft,
                entry: isolatedEntry
            )

            apply(
                draft: editedEntryResolution.draft,
                quantityMode: quantityMode,
                quantityAmount: quantityAmount,
                secondaryNutrientBackfillState: editedEntryResolution.secondaryNutrientBackfillState,
                to: isolatedEntry
            )
        }

        WidgetTimelineReloader.reloadMacroWidgets()
    }

    func delete(entry: LogEntry, operation: String) throws {
        let entryID = entry.persistentModelID

        try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            guard let isolatedEntry = isolatedContext.model(for: entryID) as? LogEntry else {
                throw NSError(
                    domain: "LogEntryRepository", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to load log entry for deletion."])
            }

            isolatedContext.delete(isolatedEntry)
        }

        WidgetTimelineReloader.reloadMacroWidgets()
    }

    func logAgain(entry: LogEntry, loggedAt: Date = .now, operation: String) throws {
        let draft = FoodDraft(logEntry: entry, saveAsCustomFood: false)
        let quantityMode = entry.quantityModeKind
        let quantityAmount = quantityMode == .servings ? (entry.servingsConsumed ?? 0) : (entry.gramsConsumed ?? 0)

        try logFood(
            draft: draft,
            reusableFoodPersistenceMode: .none,
            loggedAt: loggedAt,
            quantityMode: quantityMode,
            quantityAmount: quantityAmount,
            operation: operation
        )
    }

    func logFood(
        draft: FoodDraft,
        reusableFoodPersistenceMode: ReusableFoodPersistenceMode,
        loggedAt: Date = .now,
        quantityMode: QuantityMode,
        quantityAmount: Double,
        operation: String
    ) throws {
        let normalizedDraft = draft.normalized()
        if let validationError = normalizedDraft.validationErrorForLogging(
            quantityMode: quantityMode,
            quantityAmount: quantityAmount
        ) {
            throw validationError
        }

        try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            let resolvedDraft = try resolvedLoggedFoodDraft(
                from: normalizedDraft,
                reusableFoodPersistenceMode: reusableFoodPersistenceMode,
                in: isolatedContext
            )
            let entry = makeLogEntry(
                draft: resolvedDraft,
                loggedAt: loggedAt,
                quantityMode: quantityMode,
                quantityAmount: quantityAmount,
                secondaryNutrientBackfillState: SecondaryNutrientBackfillPolicy.resolvedStateForNewRecord(from: resolvedDraft)
            )

            isolatedContext.insert(entry)
        }

        WidgetTimelineReloader.reloadMacroWidgets()
    }

    private func apply(
        draft: FoodDraft,
        quantityMode: QuantityMode,
        quantityAmount: Double,
        secondaryNutrientBackfillState: SecondaryNutrientBackfillState?,
        to entry: LogEntry
    ) {
        let values = resolvedEntryValues(
            from: draft,
            quantityMode: quantityMode,
            quantityAmount: quantityAmount
        )

        entry.apply(values)
        entry.secondaryNutrientBackfillState = secondaryNutrientBackfillState
        entry.updatedAt = .now
    }

    private func makeLogEntry(
        draft: FoodDraft,
        loggedAt: Date,
        quantityMode: QuantityMode,
        quantityAmount: Double,
        secondaryNutrientBackfillState: SecondaryNutrientBackfillState?
    ) -> LogEntry {
        let values = resolvedEntryValues(
            from: draft,
            quantityMode: quantityMode,
            quantityAmount: quantityAmount
        )

        return LogEntry(
            values: values,
            dateLogged: loggedAt,
            secondaryNutrientBackfillState: secondaryNutrientBackfillState
        )
    }

    private func resolvedLoggedFoodDraft(
        from draft: FoodDraft,
        reusableFoodPersistenceMode: ReusableFoodPersistenceMode,
        in context: ModelContext
    ) throws -> FoodDraft {
        guard reusableFoodPersistenceMode.shouldPersistReusableFood else {
            return draft
        }

        let storedFood = try FoodItemRepository(modelContext: context).upsertReusableFood(from: draft, in: context)
        return FoodDraft(foodItem: storedFood, saveAsCustomFood: draft.saveAsCustomFood)
    }

    private func resolvedEditedEntry(from draft: FoodDraft, entry: LogEntry) -> EditedEntryResolution {
        let initialDraft = FoodDraft(logEntry: entry, saveAsCustomFood: false)
        let hasMeaningfulChanges = draft.hasMeaningfulChanges(comparedTo: initialDraft)
        let baselineState =
            entry.secondaryNutrientBackfillState
            ?? SecondaryNutrientBackfillPolicy.inferredState(for: entry)
        let secondaryNutrientUpdate = SecondaryNutrientBackfillPolicy.resolvedUpdate(
            initialDraft: initialDraft,
            updatedDraft: draft,
            initialState: baselineState
        )

        var editedDraft = secondaryNutrientUpdate.draft
        if initialDraft.foodItemID != nil, hasMeaningfulChanges {
            editedDraft.foodItemID = nil
        }

        return EditedEntryResolution(
            draft: editedDraft,
            secondaryNutrientBackfillState: secondaryNutrientUpdate.state
        )
    }

    private func resolvedEntryValues(
        from draft: FoodDraft,
        quantityMode: QuantityMode,
        quantityAmount: Double
    ) -> EntryValues {
        let consumedNutrients = NutritionMath.consumedNutrients(for: draft, mode: quantityMode, amount: quantityAmount)

        return EntryValues(
            draft: draft,
            quantityMode: quantityMode,
            quantityAmount: quantityAmount,
            consumedNutrients: consumedNutrients
        )
    }
}

private extension LogEntry {
    convenience init(
        values: LogEntryRepository.EntryValues,
        dateLogged: Date,
        secondaryNutrientBackfillState: SecondaryNutrientBackfillState?
    ) {
        self.init(
            foodItemID: values.foodItemID,
            dateLogged: dateLogged,
            foodName: values.foodName,
            brand: values.brand,
            source: values.source,
            barcode: values.barcode,
            externalProductID: values.externalProductID,
            sourceName: values.sourceName,
            sourceURL: values.sourceURL,
            servingDescription: values.servingDescription,
            gramsPerServing: values.gramsPerServing,
            caloriesPerServing: values.perServingNutrition.calories,
            proteinPerServing: values.perServingNutrition.protein,
            fatPerServing: values.perServingNutrition.fat,
            carbsPerServing: values.perServingNutrition.carbs,
            saturatedFatPerServing: values.perServingNutrition.saturatedFat,
            fiberPerServing: values.perServingNutrition.fiber,
            sugarsPerServing: values.perServingNutrition.sugars,
            addedSugarsPerServing: values.perServingNutrition.addedSugars,
            sodiumPerServing: values.perServingNutrition.sodium,
            cholesterolPerServing: values.perServingNutrition.cholesterol,
            quantityMode: values.quantityMode,
            servingsConsumed: values.servingsConsumed,
            gramsConsumed: values.gramsConsumed,
            caloriesConsumed: values.consumedNutrients.calories,
            proteinConsumed: values.consumedNutrients.protein,
            fatConsumed: values.consumedNutrients.fat,
            carbsConsumed: values.consumedNutrients.carbs,
            saturatedFatConsumed: values.consumedNutrients.saturatedFat,
            fiberConsumed: values.consumedNutrients.fiber,
            sugarsConsumed: values.consumedNutrients.sugars,
            addedSugarsConsumed: values.consumedNutrients.addedSugars,
            sodiumConsumed: values.consumedNutrients.sodium,
            cholesterolConsumed: values.consumedNutrients.cholesterol,
            secondaryNutrientBackfillState: secondaryNutrientBackfillState
        )
    }

    func apply(_ values: LogEntryRepository.EntryValues) {
        foodName = values.foodName
        brand = values.brand
        source = values.source.rawValue
        foodItemID = values.foodItemID
        barcode = values.barcode
        externalProductID = values.externalProductID
        sourceName = values.sourceName
        sourceURL = values.sourceURL
        servingDescription = values.servingDescription
        gramsPerServing = values.gramsPerServing
        caloriesPerServing = values.perServingNutrition.calories
        proteinPerServing = values.perServingNutrition.protein
        fatPerServing = values.perServingNutrition.fat
        carbsPerServing = values.perServingNutrition.carbs
        saturatedFatPerServing = values.perServingNutrition.saturatedFat
        fiberPerServing = values.perServingNutrition.fiber
        sugarsPerServing = values.perServingNutrition.sugars
        addedSugarsPerServing = values.perServingNutrition.addedSugars
        sodiumPerServing = values.perServingNutrition.sodium
        cholesterolPerServing = values.perServingNutrition.cholesterol
        quantityMode = values.quantityMode.rawValue
        servingsConsumed = values.servingsConsumed
        gramsConsumed = values.gramsConsumed
        caloriesConsumed = values.consumedNutrients.calories
        proteinConsumed = values.consumedNutrients.protein
        fatConsumed = values.consumedNutrients.fat
        carbsConsumed = values.consumedNutrients.carbs
        saturatedFatConsumed = values.consumedNutrients.saturatedFat
        fiberConsumed = values.consumedNutrients.fiber
        sugarsConsumed = values.consumedNutrients.sugars
        addedSugarsConsumed = values.consumedNutrients.addedSugars
        sodiumConsumed = values.consumedNutrients.sodium
        cholesterolConsumed = values.consumedNutrients.cholesterol
    }
}
