import Foundation
import SwiftData

extension LogEntryRepository {
    struct EditedEntryResolution {
        let draft: FoodDraft
        let secondaryNutrientBackfillState: SecondaryNutrientBackfillState?
    }

    struct EntryValues {
        let foodItemID: UUID?
        let foodName: String
        let brand: String?
        let source: FoodSource
        let barcode: String?
        let externalProductID: String?
        let sourceName: String?
        let sourceURL: String?
        let servingDescription: String
        let gramsPerServing: Double?
        let perServingNutrition: PerServingNutritionValues
        let quantityMode: QuantityMode
        let servingsConsumed: Double?
        let gramsConsumed: Double?
        let consumedNutrients: LoggedFoodNutrients

        init(
            draft: FoodDraft,
            quantityMode: QuantityMode,
            quantityAmount: Double,
            consumedNutrients: LoggedFoodNutrients
        ) {
            self.foodItemID = draft.foodItemID
            self.foodName = draft.name
            self.brand = draft.brandOrNil
            self.source = draft.source
            self.barcode = draft.barcodeOrNil
            self.externalProductID = draft.externalProductIDOrNil
            self.sourceName = draft.sourceNameOrNil
            self.sourceURL = draft.sourceURLOrNil
            self.servingDescription = draft.servingDescription
            self.gramsPerServing = draft.gramsPerServing
            perServingNutrition = draft.perServingNutritionValues
            self.quantityMode = quantityMode
            self.servingsConsumed = quantityMode == .servings ? quantityAmount : nil
            self.gramsConsumed = quantityMode == .grams ? quantityAmount : nil
            self.consumedNutrients = consumedNutrients
        }
    }

    func apply(
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

    func makeLogEntry(
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

    func resolvedEditedEntry(from draft: FoodDraft, entry: LogEntry) -> EditedEntryResolution {
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

    func resolvedEntryValues(
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

    func mealComponentSnapshots(for logEntryID: UUID, in context: ModelContext) throws -> [LoggedMealComponentSnapshot] {
        let descriptor = FetchDescriptor<LoggedMealComponentSnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.logEntryID == logEntryID
            }
        )
        return try context.fetch(descriptor)
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
        mealID = nil
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
