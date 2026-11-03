import Foundation
import OSLog
import SwiftData

extension SecondaryNutrientRepairService {
    private struct ExternalFoodRepairTarget {
        let foodID: UUID
        let source: FoodSource
        let target: SecondaryNutrientRepairTarget
    }

    enum HistoricalEntryRepairDraftResolution {
        case draft(FoodDraft)
        case notRepairable
    }

    private struct LogEntrySecondaryNutrientRepair {
        let entryID: PersistentIdentifier
        let originalData: FoodDraftImportedData
        let draft: FoodDraft
    }

    static func repairExternalFoodsIfNeeded(modelContext: ModelContext) async throws {
        let targets = try externalFoodRepairTargets(modelContext: modelContext)
        guard targets.isEmpty == false else { return }

        let repository = FoodItemRepository(modelContext: modelContext)
        for target in targets {
            do {
                guard let existingFood = try repository.fetchReusableFood(id: target.foodID),
                    let refreshedDraft = try await refreshedDraft(source: target.source, target: target.target)
                else {
                    continue
                }

                let existingDraft = FoodDraft(foodItem: existingFood)
                guard existingDraft.secondaryNutrientRepairKey == refreshedDraft.secondaryNutrientRepairKey else {
                    try repository.saveReusableFood(
                        from: existingDraft,
                        operation: "Mark reusable food secondary nutrients not repairable",
                        secondaryNutrientBackfillStateOverride: .notRepairable
                    )
                    continue
                }

                guard refreshedDraft.hasAnySecondaryNutrient else {
                    try repository.saveReusableFood(
                        from: existingDraft,
                        operation: "Mark reusable food secondary nutrients not repairable",
                        secondaryNutrientBackfillStateOverride: .notRepairable
                    )
                    continue
                }

                let repairedDraft = existingDraft.backfillingSourceIdentity(from: refreshedDraft)
                    .withSecondaryNutrients(from: refreshedDraft)
                try repository.saveReusableFood(
                    from: repairedDraft,
                    operation: "Repair reusable food secondary nutrients",
                    secondaryNutrientBackfillStateOverride: .current
                )
            } catch {
                logger.error(
                    "Repair reusable food secondary nutrients skipped for \(target.foodID.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    static func repairLogEntryFoodLinksIfNeeded(modelContext: ModelContext) throws {
        let foodIDsByKey = try repairableFoodIDsByKey(modelContext: modelContext)
        guard foodIDsByKey.isEmpty == false else { return }

        let entries = try logEntriesNeedingFoodLinkRepair(modelContext: modelContext)
        guard entries.isEmpty == false else { return }

        try PersistenceReporter.persist(modelContext: modelContext, operation: "Repair log entry food links") {
            for entry in entries {
                guard let foodID = foodIDsByKey[entry.secondaryNutrientRepairKey] else { continue }
                entry.foodItemID = foodID
            }
        }
    }

    static func repairLogEntrySecondaryNutrientsIfNeeded(
        modelContext: ModelContext,
        commonFoodRecords: [CommonFoodSeedRecord]
    ) async throws {
        let entries = try logEntriesNeedingSecondaryNutrientRepair(modelContext: modelContext)
        guard entries.isEmpty == false else { return }

        let lookup = try historicalRepairLookup(modelContext: modelContext)
        let repairDraftsByKey = commonRepairDraftsByKey(records: commonFoodRecords)
        var externalDraftsByTarget: [SecondaryNutrientRepairTarget: FoodDraft?] = [:]
        var repairs: [LogEntrySecondaryNutrientRepair] = []
        var notRepairableEntries: [PersistentIdentifier: FoodDraftImportedData] = [:]

        for entry in entries {
            let originalData = entry.importedData
            let repairDraftResolution = try await historicalRepairDraftResolution(
                for: entry,
                foodsByID: lookup.foodsByID,
                externalTargetsByKey: lookup.externalTargetsByKey,
                commonDraftsByKey: repairDraftsByKey,
                externalDraftsByTarget: &externalDraftsByTarget
            )

            switch repairDraftResolution {
            case let .draft(sourceDraft):
                let repairedDraft = FoodDraft(logEntry: entry)
                    .backfillingSourceIdentity(from: sourceDraft)
                    .withSecondaryNutrients(from: sourceDraft)

                repairs.append(
                    LogEntrySecondaryNutrientRepair(
                        entryID: entry.persistentModelID,
                        originalData: originalData,
                        draft: repairedDraft
                    )
                )
            case .notRepairable:
                notRepairableEntries[entry.persistentModelID] = originalData
            }
        }

        guard repairs.isEmpty == false || notRepairableEntries.isEmpty == false else { return }

        try PersistenceReporter.persist(modelContext: modelContext, operation: "Repair log entry secondary nutrients") {
            for repair in repairs {
                guard let entry = modelContext.model(for: repair.entryID) as? LogEntry,
                    !entry.isDeleted, entry.importedData == repair.originalData
                else {
                    continue
                }

                // Quantity may change while later lookups await; food edits invalidate the repair.
                let draft = repair.draft
                let amount = entry.quantityModeKind == .servings ? (entry.servingsConsumed ?? 0) : (entry.gramsConsumed ?? 0)
                let consumed = NutritionMath.consumedNutrients(for: draft, mode: entry.quantityModeKind, amount: amount)
                entry.barcode = draft.barcodeOrNil
                entry.externalProductID = draft.externalProductIDOrNil
                entry.sourceName = draft.sourceNameOrNil
                entry.sourceURL = draft.sourceURLOrNil
                entry.saturatedFatPerServing = draft.saturatedFatPerServing
                entry.fiberPerServing = draft.fiberPerServing
                entry.sugarsPerServing = draft.sugarsPerServing
                entry.addedSugarsPerServing = draft.addedSugarsPerServing
                entry.sodiumPerServing = draft.sodiumPerServing
                entry.cholesterolPerServing = draft.cholesterolPerServing
                entry.saturatedFatConsumed = consumed.saturatedFat
                entry.fiberConsumed = consumed.fiber
                entry.sugarsConsumed = consumed.sugars
                entry.addedSugarsConsumed = consumed.addedSugars
                entry.sodiumConsumed = consumed.sodium
                entry.cholesterolConsumed = consumed.cholesterol
                entry.secondaryNutrientBackfillState = .current
                entry.updatedAt = .now
            }

            for (entryID, originalData) in notRepairableEntries {
                guard let entry = modelContext.model(for: entryID) as? LogEntry,
                    !entry.isDeleted, entry.importedData == originalData
                else {
                    continue
                }

                entry.secondaryNutrientBackfillState = .notRepairable
                entry.updatedAt = .now
            }
        }
    }

    private static func externalFoodRepairTargets(modelContext: ModelContext) throws -> [ExternalFoodRepairTarget] {
        let needsRepairRaw = SecondaryNutrientBackfillState.needsRepair.rawValue
        let foods = try modelContext.fetch(
            FetchDescriptor<FoodItem>(predicate: #Predicate { $0.secondaryNutrientBackfillStateRaw == needsRepairRaw })
        )
        return foods.compactMap { food in
            guard let target = food.secondaryNutrientRepairTarget else {
                return nil
            }

            return ExternalFoodRepairTarget(
                foodID: food.id,
                source: food.sourceKind,
                target: target
            )
        }
    }

    static func repairableFoodIDsByKey(modelContext: ModelContext) throws -> [SecondaryNutrientRepairKey: UUID] {
        unambiguousValuesByKey(try commonFoods(modelContext: modelContext)) { $0.secondaryNutrientRepairKey }
            .mapValues(\.id)
    }

    static func logEntriesNeedingFoodLinkRepair(modelContext: ModelContext) throws -> [LogEntry] {
        let commonSource = FoodSource.common.rawValue
        let needsRepairRaw = SecondaryNutrientBackfillState.needsRepair.rawValue
        return try modelContext.fetch(
            FetchDescriptor<LogEntry>(
                predicate: #Predicate { entry in
                    entry.foodItemID == nil
                        && entry.secondaryNutrientBackfillStateRaw == needsRepairRaw
                        && entry.source == commonSource
                }
            )
        )
    }

    static func logEntriesNeedingSecondaryNutrientRepair(modelContext: ModelContext) throws -> [LogEntry] {
        let needsRepairRaw = SecondaryNutrientBackfillState.needsRepair.rawValue
        return try modelContext.fetch(
            FetchDescriptor<LogEntry>(predicate: #Predicate { $0.secondaryNutrientBackfillStateRaw == needsRepairRaw })
        )
    }

    private static func commonFoods(modelContext: ModelContext) throws -> [FoodItem] {
        let commonSource = FoodSource.common.rawValue
        return try modelContext.fetch(
            FetchDescriptor<FoodItem>(predicate: #Predicate { $0.source == commonSource })
        )
    }
}
