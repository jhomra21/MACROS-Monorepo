import Foundation
import SwiftData

extension FoodItemRepository {
    @discardableResult
    func saveReusableFood(
        from draft: FoodDraft,
        operation: String,
        sourceOverride: FoodSource? = nil,
        secondaryNutrientBackfillStateOverride: SecondaryNutrientBackfillState? = nil
    ) throws -> FoodItem {
        let savedFoodID = try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            let savedFood = try upsertReusableFood(
                from: draft,
                in: isolatedContext,
                sourceOverride: sourceOverride,
                secondaryNutrientBackfillStateOverride: secondaryNutrientBackfillStateOverride
            )
            try MealRepository(modelContext: isolatedContext).refreshSearchableTextForMealsReferencingFood(
                id: savedFood.id,
                in: isolatedContext
            )
            return savedFood.id
        }

        guard let savedFood = try fetchReusableFood(id: savedFoodID) else {
            throw NSError(domain: "FoodItemRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load saved food."])
        }

        return savedFood
    }

    func deleteReusableFood(_ food: FoodItem, operation: String) throws {
        let foodID = food.persistentModelID

        try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            guard let isolatedFood = isolatedContext.model(for: foodID) as? FoodItem else {
                throw NSError(
                    domain: "FoodItemRepository", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to load saved food for deletion."])
            }

            guard isolatedFood.sourceKind != .common else {
                throw NSError(
                    domain: "FoodItemRepository", code: 3, userInfo: [NSLocalizedDescriptionKey: "Common foods cannot be deleted."])
            }

            let referencingMealCount = try MealRepository(modelContext: isolatedContext).mealCountReferencingFood(
                id: isolatedFood.id,
                in: isolatedContext
            )
            guard referencingMealCount == 0 else {
                throw NSError(
                    domain: "FoodItemRepository",
                    code: 4,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "This food is used by \(referencingMealCount) meal\(referencingMealCount == 1 ? "" : "s") and cannot be deleted."
                    ]
                )
            }

            isolatedContext.delete(isolatedFood)
            #if DEBUG
            try throwDebugForcedFailure("debugFailSavedFoodDeletes")
            #endif
        }
    }

    /// Inserts a deleted reusable food again with its original identity and values.
    func restoreReusableFood(_ food: FoodItem, operation: String) throws {
        try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            guard try savedFoodDuplicating(food, in: isolatedContext) == nil else {
                throw NSError(
                    domain: "FoodItemRepository",
                    code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "\(food.name) was saved again, so there is nothing to undo."]
                )
            }

            isolatedContext.insert(food)
            #if DEBUG
            try throwDebugForcedFailure("debugFailSavedFoodRestores")
            #endif
        }
    }

    /// A saved food that `food` would duplicate if inserted again: the same row, or an external food with the same
    /// external product ID or barcode (any alias) from either lookup provider. Saving does not merge a USDA search food
    /// with an Open Food Facts scan of the same barcode, but for Undo they are the same product.
    private func savedFoodDuplicating(_ food: FoodItem, in context: ModelContext) throws -> FoodItem? {
        if let sameFood = try fetchReusableFood(id: food.id, in: context) {
            return sameFood
        }

        guard preservesExternalIdentity(for: food.sourceKind) else {
            return nil
        }

        let externalSources: [FoodSource] = [.barcodeLookup, .searchLookup]
        if let externalProductID = food.externalProductID {
            for source in externalSources {
                if let match = try fetchReusableFood(source: source, externalProductID: externalProductID, in: context) {
                    return match
                }
            }
        }

        guard let barcode = food.barcode else {
            return nil
        }

        return try fetchBarcodeFood(barcode: barcode, preferredSources: externalSources, in: context)
    }

    @discardableResult
    func upsertReusableFood(
        from draft: FoodDraft,
        in context: ModelContext,
        sourceOverride: FoodSource? = nil,
        secondaryNutrientBackfillStateOverride: SecondaryNutrientBackfillState? = nil
    ) throws -> FoodItem {
        let normalizedDraft = draft.normalized()
        if let validationError = normalizedDraft.validationErrorForSaving() {
            throw validationError
        }

        let existingFood = try reusableFood(for: normalizedDraft, in: context)
        let resolvedSource = resolvedReusableSource(
            for: normalizedDraft,
            existingFood: existingFood,
            sourceOverride: sourceOverride
        )
        let persistedDraft = resolvedPersistenceDraft(
            from: normalizedDraft,
            existingFood: existingFood,
            resolvedSource: resolvedSource
        )
        let secondaryNutrientUpdate = resolvedSecondaryNutrientUpdate(
            for: persistedDraft,
            existingFood: existingFood,
            override: secondaryNutrientBackfillStateOverride
        )
        let food = existingFood ?? normalizedDraft.makeReusableFoodItem(sourceOverride: resolvedSource)

        if food.modelContext == nil {
            context.insert(food)
        }

        apply(
            secondaryNutrientUpdate.draft,
            source: resolvedSource,
            secondaryNutrientBackfillState: secondaryNutrientUpdate.state,
            to: food
        )
        return food
    }

    private func resolvedReusableSource(
        for draft: FoodDraft,
        existingFood: FoodItem?,
        sourceOverride: FoodSource?
    ) -> FoodSource {
        if let sourceOverride {
            return sourceOverride
        }

        if let existingFood {
            return existingFood.sourceKind
        }

        switch draft.source {
        case .common:
            return .custom
        case .custom, .barcodeLookup, .labelScan, .searchLookup:
            return draft.source
        }
    }

    private func resolvedPersistenceDraft(
        from draft: FoodDraft,
        existingFood: FoodItem?,
        resolvedSource: FoodSource
    ) -> FoodDraft {
        guard let existingFood, preservesExternalIdentity(for: resolvedSource) else {
            return draft
        }

        var persistedDraft = draft

        if persistedDraft.barcodeOrNil == nil {
            persistedDraft.barcode = existingFood.barcode ?? ""
        }

        if persistedDraft.externalProductIDOrNil == nil {
            persistedDraft.externalProductID = existingFood.externalProductID ?? ""
        }

        if persistedDraft.sourceNameOrNil == nil {
            persistedDraft.sourceName = existingFood.sourceName ?? ""
        }

        if persistedDraft.sourceURLOrNil == nil {
            persistedDraft.sourceURL = existingFood.sourceURL ?? ""
        }

        return persistedDraft
    }

    private func preservesExternalIdentity(for source: FoodSource) -> Bool {
        switch source {
        case .barcodeLookup, .searchLookup:
            return true
        case .common, .custom, .labelScan:
            return false
        }
    }

    private func resolvedSecondaryNutrientUpdate(
        for draft: FoodDraft,
        existingFood: FoodItem?,
        override: SecondaryNutrientBackfillState?
    ) -> SecondaryNutrientBackfillPolicy.UpdateResolution {
        if let override {
            return .init(draft: draft, state: override)
        }

        guard let existingFood else {
            return .init(
                draft: draft,
                state: SecondaryNutrientBackfillPolicy.resolvedStateForNewRecord(from: draft)
            )
        }

        let initialDraft = FoodDraft(foodItem: existingFood)
        let baselineState =
            existingFood.secondaryNutrientBackfillState
            ?? SecondaryNutrientBackfillPolicy.inferredState(for: existingFood)

        return SecondaryNutrientBackfillPolicy.resolvedUpdate(
            initialDraft: initialDraft,
            updatedDraft: draft,
            initialState: baselineState
        )
    }

    private func apply(
        _ draft: FoodDraft,
        source: FoodSource,
        secondaryNutrientBackfillState: SecondaryNutrientBackfillState?,
        to food: FoodItem
    ) {
        let perServingNutrition = draft.perServingNutritionValues
        food.name = draft.name
        food.brand = draft.brandOrNil
        food.source = source.rawValue
        food.barcode = draft.barcodeOrNil
        food.externalProductID = draft.externalProductIDOrNil
        food.sourceName = draft.sourceNameOrNil
        food.sourceURL = draft.sourceURLOrNil
        food.servingDescription = draft.servingDescription
        food.gramsPerServing = draft.gramsPerServing
        food.caloriesPerServing = perServingNutrition.calories
        food.proteinPerServing = perServingNutrition.protein
        food.fatPerServing = perServingNutrition.fat
        food.carbsPerServing = perServingNutrition.carbs
        food.saturatedFatPerServing = perServingNutrition.saturatedFat
        food.fiberPerServing = perServingNutrition.fiber
        food.sugarsPerServing = perServingNutrition.sugars
        food.addedSugarsPerServing = perServingNutrition.addedSugars
        food.sodiumPerServing = perServingNutrition.sodium
        food.cholesterolPerServing = perServingNutrition.cholesterol
        food.secondaryNutrientBackfillState = secondaryNutrientBackfillState
        food.normalizeForPersistence()
    }
}

#if DEBUG
private var debugForcedFailureCounts: [String: Int] = [:]

/// E2E hook: launching with `-<key> <n>` makes the next n matching saves throw after their changes are staged,
/// so `PersistenceReporter` exercises its real rollback path.
private func throwDebugForcedFailure(_ key: String) throws {
    let remaining = debugForcedFailureCounts[key] ?? UserDefaults.standard.integer(forKey: key)
    debugForcedFailureCounts[key] = max(0, remaining - 1)
    guard remaining > 0 else { return }
    throw NSError(domain: "DebugForcedFailure", code: 1, userInfo: [NSLocalizedDescriptionKey: "Forced save failure (DEBUG)."])
}
#endif
