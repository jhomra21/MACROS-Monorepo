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
        let barcode: String?
        let externalProductID: String?
        let sourceName: String?
        let sourceURL: String?
        let perServing: SecondaryNutrientValues
        let consumed: SecondaryNutrientValues
    }

    private struct SecondaryNutrientValues {
        let saturatedFat: Double?
        let fiber: Double?
        let sugars: Double?
        let addedSugars: Double?
        let sodium: Double?
        let cholesterol: Double?
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

        let foodsByID = try Dictionary(
            uniqueKeysWithValues: fetchAllFoods(modelContext: modelContext).map { ($0.id, $0) }
        )
        let externalTargetsByKey = repairableExternalTargetsByKey(foodsByID: foodsByID)
        let repairDraftsByKey = commonRepairDraftsByKey(records: commonFoodRecords)
        var externalDraftsByTarget: [SecondaryNutrientRepairTarget: FoodDraft?] = [:]
        var repairs: [LogEntrySecondaryNutrientRepair] = []
        var notRepairableEntryIDs: [PersistentIdentifier] = []

        for entry in entries {
            let repairDraftResolution = try await historicalRepairDraftResolution(
                for: entry,
                foodsByID: foodsByID,
                externalTargetsByKey: externalTargetsByKey,
                commonDraftsByKey: repairDraftsByKey,
                externalDraftsByTarget: &externalDraftsByTarget
            )

            switch repairDraftResolution {
            case let .draft(sourceDraft):
                let repairedDraft = FoodDraft(logEntry: entry)
                    .backfillingSourceIdentity(from: sourceDraft)
                    .withSecondaryNutrients(from: sourceDraft)

                let quantityAmount =
                    entry.quantityModeKind == .servings
                    ? (entry.servingsConsumed ?? 0)
                    : (entry.gramsConsumed ?? 0)
                let consumedNutrients = NutritionMath.consumedNutrients(
                    for: repairedDraft,
                    mode: entry.quantityModeKind,
                    amount: quantityAmount
                )

                repairs.append(
                    LogEntrySecondaryNutrientRepair(
                        entryID: entry.persistentModelID,
                        barcode: repairedDraft.barcodeOrNil,
                        externalProductID: repairedDraft.externalProductIDOrNil,
                        sourceName: repairedDraft.sourceNameOrNil,
                        sourceURL: repairedDraft.sourceURLOrNil,
                        perServing: SecondaryNutrientValues(
                            saturatedFat: repairedDraft.saturatedFatPerServing,
                            fiber: repairedDraft.fiberPerServing,
                            sugars: repairedDraft.sugarsPerServing,
                            addedSugars: repairedDraft.addedSugarsPerServing,
                            sodium: repairedDraft.sodiumPerServing,
                            cholesterol: repairedDraft.cholesterolPerServing
                        ),
                        consumed: SecondaryNutrientValues(
                            saturatedFat: consumedNutrients.saturatedFat,
                            fiber: consumedNutrients.fiber,
                            sugars: consumedNutrients.sugars,
                            addedSugars: consumedNutrients.addedSugars,
                            sodium: consumedNutrients.sodium,
                            cholesterol: consumedNutrients.cholesterol
                        )
                    )
                )
            case .notRepairable:
                notRepairableEntryIDs.append(entry.persistentModelID)
            }
        }

        guard repairs.isEmpty == false || notRepairableEntryIDs.isEmpty == false else { return }

        try PersistenceReporter.persist(modelContext: modelContext, operation: "Repair log entry secondary nutrients") {
            for repair in repairs {
                guard let entry = modelContext.model(for: repair.entryID) as? LogEntry else {
                    continue
                }

                entry.barcode = repair.barcode
                entry.externalProductID = repair.externalProductID
                entry.sourceName = repair.sourceName
                entry.sourceURL = repair.sourceURL
                entry.saturatedFatPerServing = repair.perServing.saturatedFat
                entry.fiberPerServing = repair.perServing.fiber
                entry.sugarsPerServing = repair.perServing.sugars
                entry.addedSugarsPerServing = repair.perServing.addedSugars
                entry.sodiumPerServing = repair.perServing.sodium
                entry.cholesterolPerServing = repair.perServing.cholesterol
                entry.saturatedFatConsumed = repair.consumed.saturatedFat
                entry.fiberConsumed = repair.consumed.fiber
                entry.sugarsConsumed = repair.consumed.sugars
                entry.addedSugarsConsumed = repair.consumed.addedSugars
                entry.sodiumConsumed = repair.consumed.sodium
                entry.cholesterolConsumed = repair.consumed.cholesterol
                entry.secondaryNutrientBackfillState = .current
                entry.updatedAt = .now
            }

            for entryID in notRepairableEntryIDs {
                guard let entry = modelContext.model(for: entryID) as? LogEntry else {
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
