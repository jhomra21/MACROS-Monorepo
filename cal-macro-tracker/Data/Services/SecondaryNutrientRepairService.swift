import Foundation
import OSLog
import SwiftData

@MainActor
enum SecondaryNutrientRepairService {
    private static let logger = Logger(subsystem: "juan-test.cal-macro-tracker", category: "SecondaryNutrientRepair")

    private struct ExternalFoodRepairTarget {
        let foodID: UUID
        let source: FoodSource
        let target: SecondaryNutrientRepairTarget
    }

    private enum HistoricalEntryRepairDraftResolution {
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

    static func requiresRepairPass(modelContext: ModelContext) throws -> Bool {
        let foods = try fetchAllFoods(modelContext: modelContext)
        if foods.contains(where: needsBackfillStateClassification) {
            return true
        }

        if foods.contains(where: { $0.secondaryNutrientBackfillState == .needsRepair }) {
            return true
        }

        let entries = try fetchAllLogEntries(modelContext: modelContext)
        if entries.contains(where: needsBackfillStateClassification) {
            return true
        }

        return entries.contains(where: { $0.secondaryNutrientBackfillState == .needsRepair })
    }

    static func repairIfNeeded(modelContext: ModelContext, commonFoodRecords: [CommonFoodSeedRecord]) async throws {
        try classifyBackfillStatesIfNeeded(modelContext: modelContext)
        try normalizeUnrepairableStatesIfNeeded(modelContext: modelContext)
        try CommonFoodSeedLoader.repairIfNeeded(modelContext: modelContext, records: commonFoodRecords)
        try await repairExternalFoodsIfNeeded(modelContext: modelContext)
        try repairLogEntryFoodLinksIfNeeded(modelContext: modelContext)
        try await repairLogEntrySecondaryNutrientsIfNeeded(
            modelContext: modelContext,
            commonFoodRecords: commonFoodRecords
        )
    }

    static func canManuallyRefreshSecondaryNutrients(
        for entry: LogEntry,
        currentDraft: FoodDraft,
        modelContext: ModelContext
    ) throws -> Bool {
        let initialDraft = FoodDraft(logEntry: entry, saveAsCustomFood: false)
        guard currentDraft.secondaryNutrientRepairKey == initialDraft.secondaryNutrientRepairKey else {
            return false
        }

        if currentDraft.secondaryNutrientRepairTarget != nil {
            return true
        }

        return try manualRefreshTarget(for: entry, modelContext: modelContext) != nil
    }

    static func canManuallyRefreshSecondaryNutrients(for currentDraft: FoodDraft, initialDraft: FoodDraft) -> Bool {
        currentDraft.secondaryNutrientRepairKey == initialDraft.secondaryNutrientRepairKey
            && currentDraft.secondaryNutrientRepairTarget != nil
    }

    static func manuallyRefreshedDraft(for currentDraft: FoodDraft, initialDraft: FoodDraft) async throws -> FoodDraft? {
        guard canManuallyRefreshSecondaryNutrients(for: currentDraft, initialDraft: initialDraft),
            let target = currentDraft.secondaryNutrientRepairTarget
        else {
            return nil
        }

        return try await manuallyRefreshedDraft(for: currentDraft, target: target)
    }

    static func manuallyRefreshedDraft(
        for entry: LogEntry,
        currentDraft: FoodDraft,
        modelContext: ModelContext
    ) async throws -> FoodDraft? {
        let initialDraft = FoodDraft(logEntry: entry, saveAsCustomFood: false)
        guard currentDraft.secondaryNutrientRepairKey == initialDraft.secondaryNutrientRepairKey else {
            return nil
        }

        let fallbackTarget = try manualRefreshTarget(for: entry, modelContext: modelContext)
        guard let target = currentDraft.secondaryNutrientRepairTarget ?? fallbackTarget else {
            return nil
        }

        return try await manuallyRefreshedDraft(for: currentDraft, target: target)
    }

    private static func repairExternalFoodsIfNeeded(modelContext: ModelContext) async throws {
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

    private static func repairLogEntryFoodLinksIfNeeded(modelContext: ModelContext) throws {
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

    private static func repairLogEntrySecondaryNutrientsIfNeeded(
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
        try fetchAllFoods(modelContext: modelContext)
            .compactMap { food in
                guard
                    food.secondaryNutrientBackfillState == .needsRepair,
                    let target = food.secondaryNutrientRepairTarget
                else {
                    return nil
                }

                return ExternalFoodRepairTarget(
                    foodID: food.id,
                    source: food.sourceKind,
                    target: target
                )
            }
    }

    private static func repairableFoodIDsByKey(modelContext: ModelContext) throws -> [SecondaryNutrientRepairKey: UUID] {
        var matches: [SecondaryNutrientRepairKey: UUID] = [:]
        var ambiguousKeys = Set<SecondaryNutrientRepairKey>()

        for food in try fetchAllFoods(modelContext: modelContext) where food.sourceKind == .common {
            let key = food.secondaryNutrientRepairKey
            if matches[key] != nil {
                ambiguousKeys.insert(key)
            } else {
                matches[key] = food.id
            }
        }

        ambiguousKeys.forEach { matches.removeValue(forKey: $0) }
        return matches
    }

    static func logEntriesNeedingFoodLinkRepair(modelContext: ModelContext) throws -> [LogEntry] {
        try fetchAllLogEntries(modelContext: modelContext)
            .filter { entry in
                entry.foodItemID == nil
                    && entry.secondaryNutrientBackfillState == .needsRepair
                    && entry.sourceKind == .common
            }
    }

    static func logEntriesNeedingSecondaryNutrientRepair(modelContext: ModelContext) throws -> [LogEntry] {
        try fetchAllLogEntries(modelContext: modelContext)
            .filter { $0.secondaryNutrientBackfillState == .needsRepair }
    }

    private static func fetchAllFoods(modelContext: ModelContext) throws -> [FoodItem] {
        try modelContext.fetch(FetchDescriptor<FoodItem>())
    }

    private static func fetchAllLogEntries(modelContext: ModelContext) throws -> [LogEntry] {
        try modelContext.fetch(FetchDescriptor<LogEntry>())
    }

    private static func classifyBackfillStatesIfNeeded(modelContext: ModelContext) throws {
        let foods = try fetchAllFoods(modelContext: modelContext)
        let entries = try fetchAllLogEntries(modelContext: modelContext)
        let foodsNeedingClassification = foods.filter(needsBackfillStateClassification)
        let entriesNeedingClassification = entries.filter(needsBackfillStateClassification)
        guard foodsNeedingClassification.isEmpty == false || entriesNeedingClassification.isEmpty == false else { return }

        let foodsByID = Dictionary(uniqueKeysWithValues: foods.map { ($0.id, $0) })
        let externalTargetsByKey = repairableExternalTargetsByKey(foodsByID: foodsByID)

        try PersistenceReporter.persist(modelContext: modelContext, operation: "Classify secondary nutrient backfill state") {
            for food in foodsNeedingClassification {
                food.secondaryNutrientBackfillState = SecondaryNutrientBackfillPolicy.inferredState(for: food)
            }

            for entry in entriesNeedingClassification {
                entry.secondaryNutrientBackfillState =
                    legacyLogEntryNeedsRepair(
                        entry: entry,
                        foodsByID: foodsByID,
                        externalTargetsByKey: externalTargetsByKey
                    )
                    ? .needsRepair
                    : .current
            }
        }
    }

    private static func normalizeUnrepairableStatesIfNeeded(modelContext: ModelContext) throws {
        let foods = try fetchAllFoods(modelContext: modelContext)
        let foodsByID = Dictionary(uniqueKeysWithValues: foods.map { ($0.id, $0) })
        let externalTargetsByKey = repairableExternalTargetsByKey(foodsByID: foodsByID)
        let entries = try fetchAllLogEntries(modelContext: modelContext)

        let foodIDsToMarkNotRepairable =
            foods
            .filter { food in
                food.secondaryNutrientBackfillState == .needsRepair
                    && food.sourceKind != .common
                    && food.secondaryNutrientRepairTarget == nil
            }
            .map(\.persistentModelID)

        let entryIDsToMarkNotRepairable =
            entries
            .filter { entry in
                entry.secondaryNutrientBackfillState == .needsRepair
                    && entry.sourceKind != .common
                    && historicalRepairTarget(
                        for: entry,
                        foodsByID: foodsByID,
                        externalTargetsByKey: externalTargetsByKey
                    ) == nil
            }
            .map(\.persistentModelID)

        guard foodIDsToMarkNotRepairable.isEmpty == false || entryIDsToMarkNotRepairable.isEmpty == false else {
            return
        }

        try PersistenceReporter.persist(modelContext: modelContext, operation: "Normalize unrepairable secondary nutrient states") {
            for foodID in foodIDsToMarkNotRepairable {
                guard let food = modelContext.model(for: foodID) as? FoodItem else {
                    continue
                }

                food.secondaryNutrientBackfillState = .notRepairable
                food.updatedAt = .now
            }

            for entryID in entryIDsToMarkNotRepairable {
                guard let entry = modelContext.model(for: entryID) as? LogEntry else {
                    continue
                }

                entry.secondaryNutrientBackfillState = .notRepairable
                entry.updatedAt = .now
            }
        }
    }

    private static func needsBackfillStateClassification(_ food: FoodItem) -> Bool {
        food.secondaryNutrientBackfillState == nil
    }

    private static func needsBackfillStateClassification(_ entry: LogEntry) -> Bool {
        entry.secondaryNutrientBackfillState == nil
    }

    private static func legacyLogEntryNeedsRepair(
        entry: LogEntry,
        foodsByID: [UUID: FoodItem],
        externalTargetsByKey: [SecondaryNutrientRepairKey: SecondaryNutrientRepairTarget]
    ) -> Bool {
        entry.isMissingAllSecondaryPerServingNutrients
            && entry.isMissingAllSecondaryConsumedNutrients
            && supportsHistoricalSecondaryNutrientRepair(
                entry: entry,
                foodsByID: foodsByID,
                externalTargetsByKey: externalTargetsByKey
            )
    }

    private static func refreshedDraft(source: FoodSource, target: SecondaryNutrientRepairTarget) async throws -> FoodDraft? {
        switch target {
        case let .openFoodFactsBarcode(barcode):
            let product = try await OpenFoodFactsClient().fetchProduct(barcode: barcode)
            return try BarcodeLookupMapper.makeDraft(from: product, source: source, barcode: barcode)
        case let .usdaFood(usdaFoodID):
            let food = try await USDAFoodDetailsClient().fetchFood(id: usdaFoodID)
            return USDAFoodDraftMapper.makeDraft(from: food)
        }
    }

    private static func manuallyRefreshedDraft(
        for draft: FoodDraft,
        target: SecondaryNutrientRepairTarget
    ) async throws -> FoodDraft? {
        guard let sourceDraft = try await refreshedDraft(source: draft.source, target: target) else {
            return nil
        }

        guard sourceDraft.secondaryNutrientRepairKey == draft.secondaryNutrientRepairKey else {
            return nil
        }

        var refreshedDraft = draft.backfillingSourceIdentity(from: sourceDraft)
            .withSecondaryNutrients(from: sourceDraft)
        refreshedDraft.secondaryNutrientBackfillState = .current
        return refreshedDraft
    }

    private static func historicalRepairDraftResolution(
        for entry: LogEntry,
        foodsByID: [UUID: FoodItem],
        externalTargetsByKey: [SecondaryNutrientRepairKey: SecondaryNutrientRepairTarget],
        commonDraftsByKey: [SecondaryNutrientRepairKey: FoodDraft],
        externalDraftsByTarget: inout [SecondaryNutrientRepairTarget: FoodDraft?]
    ) async throws -> HistoricalEntryRepairDraftResolution {
        switch entry.sourceKind {
        case .common:
            guard let draft = commonDraftsByKey[entry.secondaryNutrientRepairKey] else {
                return .notRepairable
            }

            return .draft(draft)
        case .barcodeLookup, .searchLookup:
            guard
                let target = historicalRepairTarget(
                    for: entry,
                    foodsByID: foodsByID,
                    externalTargetsByKey: externalTargetsByKey
                )
            else {
                return .notRepairable
            }

            let sourceDraft: FoodDraft?
            if let cachedDraft = externalDraftsByTarget[target] {
                sourceDraft = cachedDraft
            } else {
                let fetchedDraft = try await refreshedDraft(source: entry.sourceKind, target: target)
                externalDraftsByTarget[target] = fetchedDraft
                sourceDraft = fetchedDraft
            }

            guard
                let sourceDraft,
                sourceDraft.secondaryNutrientRepairKey == entry.secondaryNutrientRepairKey
            else {
                return .notRepairable
            }

            return .draft(sourceDraft)
        case .custom, .labelScan:
            return .notRepairable
        }
    }

    private static func commonRepairDraftsByKey(records: [CommonFoodSeedRecord]) -> [SecondaryNutrientRepairKey: FoodDraft] {
        var matches: [SecondaryNutrientRepairKey: FoodDraft] = [:]
        var ambiguousKeys = Set<SecondaryNutrientRepairKey>()

        for record in records {
            let draft = CommonFoodSeedLoader.makeFoodDraft(from: record)
            let key = draft.secondaryNutrientRepairKey
            if matches[key] != nil {
                ambiguousKeys.insert(key)
            } else {
                matches[key] = draft
            }
        }

        ambiguousKeys.forEach { matches.removeValue(forKey: $0) }
        return matches
    }

    private static func supportsHistoricalSecondaryNutrientRepair(
        entry: LogEntry,
        foodsByID: [UUID: FoodItem],
        externalTargetsByKey: [SecondaryNutrientRepairKey: SecondaryNutrientRepairTarget]
    ) -> Bool {
        switch entry.sourceKind {
        case .common:
            return true
        case .barcodeLookup, .searchLookup:
            return historicalRepairTarget(
                for: entry,
                foodsByID: foodsByID,
                externalTargetsByKey: externalTargetsByKey
            ) != nil
        case .custom, .labelScan:
            return false
        }
    }

    private static func historicalRepairTarget(
        for entry: LogEntry,
        foodsByID: [UUID: FoodItem],
        externalTargetsByKey: [SecondaryNutrientRepairKey: SecondaryNutrientRepairTarget]
    ) -> SecondaryNutrientRepairTarget? {
        if let target = entry.secondaryNutrientRepairTarget {
            return target
        }

        if let foodItemID = entry.foodItemID,
            let food = foodsByID[foodItemID],
            food.sourceKind != .common,
            food.secondaryNutrientRepairKey == entry.secondaryNutrientRepairKey
        {
            return food.secondaryNutrientRepairTarget
        }

        return externalTargetsByKey[entry.secondaryNutrientRepairKey]
    }

    private static func manualRefreshTarget(
        for entry: LogEntry,
        modelContext: ModelContext
    ) throws -> SecondaryNutrientRepairTarget? {
        let foodsByID = try Dictionary(
            uniqueKeysWithValues: fetchAllFoods(modelContext: modelContext).map { ($0.id, $0) }
        )
        let externalTargetsByKey = repairableExternalTargetsByKey(foodsByID: foodsByID)
        return historicalRepairTarget(
            for: entry,
            foodsByID: foodsByID,
            externalTargetsByKey: externalTargetsByKey
        )
    }

    private static func repairableExternalTargetsByKey(
        foodsByID: [UUID: FoodItem]
    ) -> [SecondaryNutrientRepairKey: SecondaryNutrientRepairTarget] {
        var matches: [SecondaryNutrientRepairKey: SecondaryNutrientRepairTarget] = [:]
        var ambiguousKeys = Set<SecondaryNutrientRepairKey>()

        for food in foodsByID.values {
            guard let target = food.secondaryNutrientRepairTarget else {
                continue
            }

            let key = food.secondaryNutrientRepairKey
            if matches[key] != nil {
                ambiguousKeys.insert(key)
            } else {
                matches[key] = target
            }
        }

        ambiguousKeys.forEach { matches.removeValue(forKey: $0) }
        return matches
    }
}
