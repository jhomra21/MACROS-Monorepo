import Foundation
import SwiftData

@MainActor
enum BackupImportMode: Equatable {
    case merge
    case replace
}

nonisolated enum BackupImportError: LocalizedError {
    case unsupportedVersion(Int)
    case invalidNutrition(String)
    case invalidWeight

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            "This backup version (\(version)) is not supported."
        case let .invalidNutrition(name):
            "The backup contains an invalid nutrition value for \(name)."
        case .invalidWeight:
            "The backup contains an invalid weight entry."
        }
    }
}

@MainActor
enum BackupImporter {
    static func decode(_ data: Data) throws -> MACROSBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = BackupDateCodec.date(from: value) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO 8601 date.")
            }
            return date
        }
        let backup = try decoder.decode(MACROSBackup.self, from: data)
        try validate(backup)
        return backup
    }

    static func validate(_ backup: MACROSBackup) throws {
        guard backup.version == 1 else { throw BackupImportError.unsupportedVersion(backup.version) }
        for goals in backup.goals {
            try validateNutrition(
                [goals.calorieGoal, goals.proteinGoalGrams, goals.fatGoalGrams, goals.carbGoalGrams],
                name: "daily goals"
            )
        }
        for food in backup.foods {
            try validateNutrition(food.nutritionValues, name: food.name)
        }
        for entry in backup.logEntries {
            try validateNutrition(entry.nutritionValues, name: entry.foodName)
            for snapshot in entry.componentSnapshots {
                try validateNutrition(snapshot.nutritionValues, name: snapshot.foodName)
            }
        }
        for meal in backup.meals {
            for component in meal.components where !component.quantityAmount.isFinite || component.quantityAmount <= 0 {
                throw BackupImportError.invalidNutrition(meal.name)
            }
        }
        guard backup.weightEntries.allSatisfy({ $0.weightKg.isFinite && $0.weightKg > 0 }) else {
            throw BackupImportError.invalidWeight
        }
    }

    static func apply(
        _ backup: MACROSBackup,
        to container: ModelContainer,
        mode: BackupImportMode,
        standardDefaults: UserDefaults = .standard,
        ringDefaults: UserDefaults? = nil,
        progress: ((String) -> Void)? = nil
    ) throws {
        try validate(backup)
        if mode == .replace {
            progress?("Replacing existing data")
            try deleteExistingData(in: container)
        }

        progress?("Importing foods")
        try importRows(
            backup.foods.filter { $0.source != .common },
            as: FoodItem.self,
            container: container,
            mode: mode,
            modelID: \.id,
            makeModel: \.model
        )

        progress?("Importing meals")
        try importMeals(backup.meals, in: container, mode: mode)

        progress?("Importing log entries")
        try importLogEntries(backup.logEntries, in: container, mode: mode)

        progress?("Importing goals")
        try importRows(backup.goals, as: DailyGoals.self, container: container, mode: mode, modelID: \.id, makeModel: \.model)

        progress?("Importing profile")
        try importRows(backup.bodyProfile, as: BodyProfile.self, container: container, mode: mode, modelID: \.id, makeModel: \.model)

        progress?("Importing weight entries")
        try importRows(backup.weightEntries, as: WeightEntry.self, container: container, mode: mode, modelID: \.id, makeModel: \.model)

        try PersistenceReporter.persist(in: container, operation: "backup.import.settings") { _ in
            backup.settings.apply(standardDefaults: standardDefaults, ringDefaults: ringDefaults)
        }
        WidgetTimelineReloader.reloadMacroWidgets()
    }

    private static func deleteExistingData(in container: ModelContainer) throws {
        try PersistenceReporter.persist(in: container, operation: "backup.replace.loggedMealSnapshots") { context in
            for row in try context.fetch(FetchDescriptor<LoggedMealComponentSnapshot>()) {
                context.delete(row)
            }
        }
        try PersistenceReporter.persist(in: container, operation: "backup.replace.logEntries") { context in
            for row in try context.fetch(FetchDescriptor<LogEntry>()) { context.delete(row) }
        }
        try PersistenceReporter.persist(in: container, operation: "backup.replace.mealComponents") { context in
            for row in try context.fetch(FetchDescriptor<MealComponent>()) { context.delete(row) }
        }
        try PersistenceReporter.persist(in: container, operation: "backup.replace.meals") { context in
            for row in try context.fetch(FetchDescriptor<Meal>()) { context.delete(row) }
        }
        try PersistenceReporter.persist(in: container, operation: "backup.replace.foods") { context in
            for row in try context.fetch(FetchDescriptor<FoodItem>()) where row.sourceKind != .common {
                context.delete(row)
            }
        }
        try PersistenceReporter.persist(in: container, operation: "backup.replace.goals") { context in
            for row in try context.fetch(FetchDescriptor<DailyGoals>()) { context.delete(row) }
        }
        try PersistenceReporter.persist(in: container, operation: "backup.replace.bodyProfile") { context in
            for row in try context.fetch(FetchDescriptor<BodyProfile>()) { context.delete(row) }
        }
        try PersistenceReporter.persist(in: container, operation: "backup.replace.weightEntries") { context in
            for row in try context.fetch(FetchDescriptor<WeightEntry>()) { context.delete(row) }
        }
    }

    private static func importRows<DTO: Identifiable, Model: PersistentModel>(
        _ rows: [DTO],
        as type: Model.Type,
        container: ModelContainer,
        mode: BackupImportMode,
        modelID: (Model) -> UUID,
        makeModel: (DTO) -> Model
    ) throws where DTO.ID == UUID {
        try PersistenceReporter.persist(in: container, operation: "backup.import.\(String(describing: type))") { context in
            var existingIDs = mode == .merge ? Set(try context.fetch(FetchDescriptor<Model>()).map(modelID)) : []
            for row in rows where existingIDs.insert(row.id).inserted {
                context.insert(makeModel(row))
            }
        }
    }

    private static func importMeals(_ meals: [BackupMeal], in container: ModelContainer, mode: BackupImportMode) throws {
        try PersistenceReporter.persist(in: container, operation: "backup.import.meals") { context in
            let existingMeals = mode == .merge ? try context.fetch(FetchDescriptor<Meal>()) : []
            var existingIDs = Set(existingMeals.map(\.id))
            var existingComponentIDs =
                mode == .merge
                ? Set(try context.fetch(FetchDescriptor<MealComponent>()).map(\.id))
                : []
            let namesByFoodID = try context.fetch(FetchDescriptor<FoodItem>()).reduce(into: [UUID: String]()) {
                $0[$1.id] = $1.name
            }
            for backupMeal in meals where !existingIDs.contains(backupMeal.id) {
                existingIDs.insert(backupMeal.id)
                let meal = backupMeal.model
                context.insert(meal)
                for component in backupMeal.components where existingComponentIDs.insert(component.id).inserted {
                    context.insert(component.model(for: backupMeal.id))
                }
                meal.updateSearchableText(
                    componentNames: backupMeal.components.compactMap { namesByFoodID[$0.foodItemID] },
                    updateTimestamp: false
                )
            }
        }
    }

    private static func importLogEntries(
        _ entries: [BackupLogEntry],
        in container: ModelContainer,
        mode: BackupImportMode
    ) throws {
        try PersistenceReporter.persist(in: container, operation: "backup.import.logEntries") { context in
            var existingIDs =
                mode == .merge
                ? Set(try context.fetch(FetchDescriptor<LogEntry>()).map(\.id))
                : []
            var existingSnapshotIDs =
                mode == .merge
                ? Set(try context.fetch(FetchDescriptor<LoggedMealComponentSnapshot>()).map(\.id))
                : []
            let foodIDs = Set(try context.fetch(FetchDescriptor<FoodItem>()).map(\.id))
            for backupEntry in entries where !existingIDs.contains(backupEntry.id) {
                existingIDs.insert(backupEntry.id)
                let entry = backupEntry.model
                if let foodItemID = entry.foodItemID, !foodIDs.contains(foodItemID) {
                    entry.foodItemID = nil
                }
                context.insert(entry)
                for snapshot in backupEntry.componentSnapshots where existingSnapshotIDs.insert(snapshot.id).inserted {
                    context.insert(snapshot.model(logEntryID: backupEntry.id))
                }
            }
        }
    }

    private static func validateNutrition(_ values: [Double?], name: String) throws {
        guard values.compactMap({ $0 }).allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw BackupImportError.invalidNutrition(name)
        }
    }
}
