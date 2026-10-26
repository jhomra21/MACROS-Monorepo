import Foundation
import SwiftData
import SwiftUI

nonisolated enum BackupImportMode: Equatable, Sendable {
    case merge
    case replace
}

nonisolated enum BackupImportError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    case invalidNutrition(String)
    case invalidWeight
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            "This backup version (\(version)) is not supported."
        case let .invalidNutrition(name):
            "The backup contains an invalid nutrition value for \(name)."
        case .invalidWeight:
            "The backup contains an invalid weight entry."
        case let .invalidValue(field):
            "The backup contains an invalid value for \(field)."
        }
    }
}

@MainActor
enum BackupImporter {
    nonisolated static func decode(_ data: Data) throws -> MACROSBackup {
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

    nonisolated static func validate(_ backup: MACROSBackup) throws {
        guard backup.version == 1 else { throw BackupImportError.unsupportedVersion(backup.version) }
        try validateDates([backup.exportedAt])
        for goals in backup.goals {
            try validateDates([goals.createdAt, goals.updatedAt])
            try validateNutrition(
                [goals.calorieGoal, goals.proteinGoalGrams, goals.fatGoalGrams, goals.carbGoalGrams],
                name: "daily goals"
            )
        }
        let currentYear = Calendar.current.component(.year, from: .now)
        for profile in backup.bodyProfile {
            try validateDates([profile.createdAt, profile.updatedAt])
            // Compare birth years before subtracting an untrusted Int from the current year.
            guard
                profile.birthYear.map({ ((currentYear - 120)...(currentYear - 1)).contains($0) }) ?? true,
                [profile.heightCm, profile.weightKg].compactMap({ $0 }).allSatisfy({ $0.isFinite && $0 > 0 }),
                profile.goalCalorieOffset.isFinite, (-750...500).contains(profile.goalCalorieOffset)
            else { throw BackupImportError.invalidValue("body profile") }
        }
        for food in backup.foods {
            try validateDates([food.createdAt, food.updatedAt])
            try validateNutrition(food.nutritionValues, name: food.name)
        }
        for entry in backup.logEntries {
            try validateDates([entry.dateLogged, entry.createdAt, entry.updatedAt])
            try validateNutrition(entry.nutritionValues, name: entry.foodName)
            for snapshot in entry.componentSnapshots {
                try validateDates([snapshot.createdAt])
                try validateNutrition(snapshot.nutritionValues, name: snapshot.foodName)
            }
        }
        for meal in backup.meals {
            try validateDates([meal.createdAt, meal.updatedAt])
            for component in meal.components {
                try validateDates([component.createdAt, component.updatedAt])
                guard component.quantityAmount.isFinite, component.quantityAmount > 0 else {
                    throw BackupImportError.invalidNutrition(meal.name)
                }
            }
        }
        guard backup.weightEntries.allSatisfy({ $0.weightKg.isFinite && $0.weightKg > 0 }) else {
            throw BackupImportError.invalidWeight
        }
        for weight in backup.weightEntries {
            try validateDates([weight.recordedAt, weight.createdAt, weight.updatedAt])
        }
        let reminders = backup.settings.reminders
        let times = [
            (reminders.hour, reminders.minute),
            (reminders.breakfastHour, reminders.breakfastMinute),
            (reminders.lunchHour, reminders.lunchMinute),
            (reminders.dinnerHour, reminders.dinnerMinute)
        ]
        // These fixed slots cannot inject identifiers or bypass the scheduler's 1-free/3-Pro cap.
        guard times.allSatisfy({ (0...23).contains($0.0) && (0...59).contains($0.1) }) else {
            throw BackupImportError.invalidValue("reminder times")
        }
        let colors = backup.settings.ringColors
        guard [colors.proteinHex, colors.carbHex, colors.fatHex].allSatisfy({ Color(hex: $0) != nil }) else {
            throw BackupImportError.invalidValue("ring colors")
        }
    }

    nonisolated private static func validateDates(_ dates: [Date]) throws {
        guard dates.allSatisfy({ $0.timeIntervalSinceReferenceDate.isFinite }) else {
            throw BackupImportError.invalidValue("dates")
        }
    }

    static func apply(
        _ backup: MACROSBackup,
        to container: ModelContainer,
        mode: BackupImportMode,
        standardDefaults: UserDefaults = .standard,
        ringDefaults: UserDefaults? = nil
    ) async throws {
        // Construct the context off the main actor so SwiftData selects a background executor.
        let importer = await Task.detached { BackupImportActor(modelContainer: container) }.value
        try await importer.apply(backup, mode: mode)
        backup.settings.apply(standardDefaults: standardDefaults, ringDefaults: ringDefaults)
    }

    nonisolated private static func validateNutrition(_ values: [Double?], name: String) throws {
        guard values.compactMap({ $0 }).allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw BackupImportError.invalidNutrition(name)
        }
    }
}

@ModelActor
actor BackupImportActor {
    func apply(_ backup: MACROSBackup, mode: BackupImportMode) throws {
        try BackupImporter.validate(backup)
        modelContext.autosaveEnabled = false
        do {
            try Task.checkCancellation()
            if mode == .replace { try deleteExistingData() }
            try importData(backup, mode: mode)
            try Task.checkCancellation()
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func importData(_ backup: MACROSBackup, mode: BackupImportMode) throws {
        try importRows(
            backup.foods.filter { $0.source != .common },
            as: FoodItem.self,
            mode: mode,
            modelID: \.id,
            makeModel: \.model
        )

        let foods = try modelContext.fetch(FetchDescriptor<FoodItem>())
        let foodsByID = foods.reduce(into: [UUID: FoodItem]()) { $0[$1.id] = $1 }
        let identifiers = Set(
            backup.meals.flatMap(\.components).compactMap(\.foodSourceIdentifier)
                + backup.logEntries.compactMap(\.foodSourceIdentifier)
                + backup.logEntries.flatMap(\.componentSnapshots).compactMap(\.foodSourceIdentifier)
        )
        let commonSource = FoodSource.common.rawValue
        let requestedIdentifiers = identifiers.map(Optional.some)
        let commonFoods = try modelContext.fetch(
            FetchDescriptor<FoodItem>(
                predicate: #Predicate { $0.source == commonSource && requestedIdentifiers.contains($0.sourceIdentifier) }
            ))
        let commonIDs = commonFoods.reduce(into: [String: UUID]()) {
            if let identifier = $1.sourceIdentifier { $0[identifier] = $1.id }
        }
        func resolvedID(_ id: UUID, _ identifier: String?) -> UUID? {
            if let identifier { return commonIDs[identifier] }
            return foodsByID[id]?.id
        }
        let meals = backup.meals.map { meal in
            var meal = meal
            meal.components = meal.components.compactMap { component in
                var component = component
                guard let id = resolvedID(component.foodItemID, component.foodSourceIdentifier) else { return nil }
                component.foodItemID = id
                return component
            }
            return meal
        }
        let entries = backup.logEntries.map { entry in
            var entry = entry
            entry.foodItemID = entry.foodItemID.flatMap { resolvedID($0, entry.foodSourceIdentifier) }
            entry.componentSnapshots = entry.componentSnapshots.map { snapshot in
                var snapshot = snapshot
                snapshot.foodItemID = resolvedID(snapshot.foodItemID, snapshot.foodSourceIdentifier) ?? snapshot.foodItemID
                return snapshot
            }
            return entry
        }
        try importMeals(meals, mode: mode)
        try importLogEntries(entries, mode: mode)
        try importRows(backup.goals, as: DailyGoals.self, mode: mode, modelID: \.id, makeModel: \.model)
        try importRows(backup.bodyProfile, as: BodyProfile.self, mode: mode, modelID: \.id, makeModel: \.model)
        try importRows(backup.weightEntries, as: WeightEntry.self, mode: mode, modelID: \.id, makeModel: \.model)
    }

    private func deleteExistingData() throws {
        let context = modelContext
        for row in try context.fetch(FetchDescriptor<LoggedMealComponentSnapshot>()) {
            context.delete(row)
        }
        for row in try context.fetch(FetchDescriptor<LogEntry>()) { context.delete(row) }
        for row in try context.fetch(FetchDescriptor<MealComponent>()) { context.delete(row) }
        for row in try context.fetch(FetchDescriptor<Meal>()) { context.delete(row) }
        for row in try context.fetch(FetchDescriptor<FoodItem>()) where row.sourceKind != .common {
            context.delete(row)
        }
        for row in try context.fetch(FetchDescriptor<DailyGoals>()) { context.delete(row) }
        for row in try context.fetch(FetchDescriptor<BodyProfile>()) { context.delete(row) }
        for row in try context.fetch(FetchDescriptor<WeightEntry>()) { context.delete(row) }
    }

    private func importRows<DTO: Identifiable, Model: PersistentModel>(
        _ rows: [DTO],
        as type: Model.Type,
        mode: BackupImportMode,
        modelID: (Model) -> UUID,
        makeModel: (DTO) -> Model
    ) throws where DTO.ID == UUID {
        let context = modelContext
        var existingIDs = mode == .merge ? Set(try context.fetch(FetchDescriptor<Model>()).map(modelID)) : []
        for row in rows where existingIDs.insert(row.id).inserted {
            context.insert(makeModel(row))
        }
    }

    private func importMeals(_ meals: [BackupMeal], mode: BackupImportMode) throws {
        let context = modelContext
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

    private func importLogEntries(
        _ entries: [BackupLogEntry],
        mode: BackupImportMode
    ) throws {
        let context = modelContext
        var existingIDs =
            mode == .merge
            ? Set(try context.fetch(FetchDescriptor<LogEntry>()).map(\.id))
            : []
        var existingSnapshotIDs =
            mode == .merge
            ? Set(try context.fetch(FetchDescriptor<LoggedMealComponentSnapshot>()).map(\.id))
            : []
        for backupEntry in entries where !existingIDs.contains(backupEntry.id) {
            existingIDs.insert(backupEntry.id)
            let entry = backupEntry.model
            context.insert(entry)
            for snapshot in backupEntry.componentSnapshots where existingSnapshotIDs.insert(snapshot.id).inserted {
                context.insert(snapshot.model(logEntryID: backupEntry.id))
            }
        }
    }
}
