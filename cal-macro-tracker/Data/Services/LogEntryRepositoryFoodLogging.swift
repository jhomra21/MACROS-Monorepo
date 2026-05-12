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
        try saveEdits(
            entry: entry,
            action: draft.loggingAction(
                quantityMode: quantityMode,
                quantityAmount: quantityAmount
            ),
            operation: operation
        )
    }

    func saveEdits(
        entry: LogEntry,
        action: FoodDraftLoggingAction,
        operation: String
    ) throws {
        if let validationError = action.validationError {
            throw validationError
        }

        let entryID = entry.persistentModelID

        try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            guard let isolatedEntry = isolatedContext.model(for: entryID) as? LogEntry else {
                throw NSError(
                    domain: "LogEntryRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load log entry for saving."])
            }

            let editedEntryResolution = resolvedEditedEntry(
                from: action.draft,
                entry: isolatedEntry
            )

            apply(
                draft: editedEntryResolution.draft,
                quantityMode: action.quantityMode,
                quantityAmount: action.quantityAmount,
                secondaryNutrientBackfillState: editedEntryResolution.secondaryNutrientBackfillState,
                to: isolatedEntry
            )
        }

        WidgetTimelineReloader.reloadMacroWidgets()
        onDailyTotalsChanged?(modelContext.container)
    }

    func delete(entry: LogEntry, operation: String) throws {
        let entryID = entry.persistentModelID

        try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            guard let isolatedEntry = isolatedContext.model(for: entryID) as? LogEntry else {
                throw NSError(
                    domain: "LogEntryRepository", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to load log entry for deletion."])
            }

            let logEntryID = isolatedEntry.id
            let snapshots = try mealComponentSnapshots(for: logEntryID, in: isolatedContext)
            for snapshot in snapshots {
                isolatedContext.delete(snapshot)
            }
            isolatedContext.delete(isolatedEntry)
        }

        WidgetTimelineReloader.reloadMacroWidgets()
        onDailyTotalsChanged?(modelContext.container)
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
        try logFood(
            action: FoodDraftLoggingAction(
                draft: draft,
                quantityMode: quantityMode,
                quantityAmount: quantityAmount,
                reusableFoodPersistenceMode: reusableFoodPersistenceMode
            ),
            loggedAt: loggedAt,
            operation: operation
        )
    }

    func logFood(
        action: FoodDraftLoggingAction,
        loggedAt: Date = .now,
        operation: String
    ) throws {
        if let validationError = action.validationError {
            throw validationError
        }

        try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            let resolvedDraft = try resolvedLoggedFoodDraft(
                from: action.draft,
                reusableFoodPersistenceMode: action.reusableFoodPersistenceMode,
                in: isolatedContext
            )
            let entry = makeLogEntry(
                draft: resolvedDraft,
                loggedAt: loggedAt,
                quantityMode: action.quantityMode,
                quantityAmount: action.quantityAmount,
                secondaryNutrientBackfillState: SecondaryNutrientBackfillPolicy.resolvedStateForNewRecord(from: resolvedDraft)
            )

            isolatedContext.insert(entry)
        }

        WidgetTimelineReloader.reloadMacroWidgets()
        onDailyTotalsChanged?(modelContext.container)
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
}
