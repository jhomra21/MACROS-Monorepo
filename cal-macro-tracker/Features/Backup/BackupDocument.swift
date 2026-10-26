import Foundation
import SwiftData

nonisolated struct MACROSBackup: Codable, Equatable, Identifiable, Sendable {
    var version: Int
    var exportedAt: Date
    var appVersion: String
    var goals: [BackupGoals]
    var bodyProfile: [BackupBodyProfile]
    var foods: [BackupFood]
    var meals: [BackupMeal]
    var logEntries: [BackupLogEntry]
    var weightEntries: [BackupWeightEntry]
    var settings: BackupSettings
    var id: Date { exportedAt }

    func replacingExportedAt(_ date: Date) -> Self {
        var copy = self
        copy.exportedAt = date
        return copy
    }
}

nonisolated struct BackupGoals: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var calorieGoal: Double
    var proteinGoalGrams: Double
    var fatGoalGrams: Double
    var carbGoalGrams: Double
    var createdAt: Date
    var updatedAt: Date

    init(_ model: DailyGoals) {
        id = model.id
        calorieGoal = model.calorieGoal
        proteinGoalGrams = model.proteinGoalGrams
        fatGoalGrams = model.fatGoalGrams
        carbGoalGrams = model.carbGoalGrams
        createdAt = model.createdAt
        updatedAt = model.updatedAt
    }

    var model: DailyGoals {
        DailyGoals(
            id: id, calorieGoal: calorieGoal, proteinGoalGrams: proteinGoalGrams,
            fatGoalGrams: fatGoalGrams, carbGoalGrams: carbGoalGrams,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

nonisolated struct BackupBodyProfile: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var sex: GoalSex
    var birthYear: Int?
    var heightCm: Double?
    var weightKg: Double?
    var activityLevel: GoalActivityLevel
    var goalCalorieOffset: Double
    var macroPreset: GoalMacroPreset
    var unitSystem: GoalUnitSystem
    var createdAt: Date
    var updatedAt: Date

    init(_ model: BodyProfile) {
        id = model.id
        sex = model.sex
        birthYear = model.birthYear
        heightCm = model.heightCm
        weightKg = model.weightKg
        activityLevel = model.activityLevel
        goalCalorieOffset = model.goalCalorieOffset
        macroPreset = model.macroPreset
        unitSystem = model.unitSystem
        createdAt = model.createdAt
        updatedAt = model.updatedAt
    }

    var model: BodyProfile {
        BodyProfile(
            id: id, sex: sex, birthYear: birthYear, heightCm: heightCm, weightKg: weightKg,
            activityLevel: activityLevel, goalCalorieOffset: goalCalorieOffset,
            macroPreset: macroPreset, unitSystem: unitSystem, createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

nonisolated struct BackupFood: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var brand: String?
    var source: FoodSource
    var sourceIdentifier: String?
    var barcode: String?
    var externalProductID: String?
    var sourceName: String?
    var sourceURL: String?
    var servingDescription: String
    var gramsPerServing: Double?
    var caloriesPerServing: Double
    var proteinPerServing: Double
    var fatPerServing: Double
    var carbsPerServing: Double
    var saturatedFatPerServing: Double?
    var fiberPerServing: Double?
    var sugarsPerServing: Double?
    var addedSugarsPerServing: Double?
    var sodiumPerServing: Double?
    var cholesterolPerServing: Double?
    var secondaryNutrientBackfillState: SecondaryNutrientBackfillState?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID, name: String, brand: String?, source: FoodSource, sourceIdentifier: String?,
        barcode: String?, externalProductID: String?, sourceName: String?, sourceURL: String?,
        servingDescription: String, gramsPerServing: Double?, caloriesPerServing: Double,
        proteinPerServing: Double, fatPerServing: Double, carbsPerServing: Double,
        saturatedFatPerServing: Double?, fiberPerServing: Double?, sugarsPerServing: Double?,
        addedSugarsPerServing: Double?, sodiumPerServing: Double?, cholesterolPerServing: Double?,
        secondaryNutrientBackfillState: SecondaryNutrientBackfillState?, createdAt: Date, updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.source = source
        self.sourceIdentifier = source == .common ? nil : sourceIdentifier
        self.barcode = barcode
        self.externalProductID = externalProductID
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.servingDescription = servingDescription
        self.gramsPerServing = gramsPerServing
        self.caloriesPerServing = caloriesPerServing
        self.proteinPerServing = proteinPerServing
        self.fatPerServing = fatPerServing
        self.carbsPerServing = carbsPerServing
        self.saturatedFatPerServing = saturatedFatPerServing
        self.fiberPerServing = fiberPerServing
        self.sugarsPerServing = sugarsPerServing
        self.addedSugarsPerServing = addedSugarsPerServing
        self.sodiumPerServing = sodiumPerServing
        self.cholesterolPerServing = cholesterolPerServing
        self.secondaryNutrientBackfillState = secondaryNutrientBackfillState
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(_ model: FoodItem) {
        self.init(
            id: model.id, name: model.name, brand: model.brand, source: model.sourceKind,
            sourceIdentifier: model.sourceIdentifier, barcode: model.barcode,
            externalProductID: model.externalProductID, sourceName: model.sourceName, sourceURL: model.sourceURL,
            servingDescription: model.servingDescription, gramsPerServing: model.gramsPerServing,
            caloriesPerServing: model.caloriesPerServing, proteinPerServing: model.proteinPerServing,
            fatPerServing: model.fatPerServing, carbsPerServing: model.carbsPerServing,
            saturatedFatPerServing: model.saturatedFatPerServing, fiberPerServing: model.fiberPerServing,
            sugarsPerServing: model.sugarsPerServing, addedSugarsPerServing: model.addedSugarsPerServing,
            sodiumPerServing: model.sodiumPerServing, cholesterolPerServing: model.cholesterolPerServing,
            secondaryNutrientBackfillState: model.secondaryNutrientBackfillState,
            createdAt: model.createdAt, updatedAt: model.updatedAt
        )
    }

    var model: FoodItem {
        FoodItem(
            id: id, name: name, brand: brand, source: source, sourceIdentifier: sourceIdentifier,
            barcode: barcode, externalProductID: externalProductID, sourceName: sourceName, sourceURL: sourceURL,
            servingDescription: servingDescription, gramsPerServing: gramsPerServing,
            caloriesPerServing: caloriesPerServing, proteinPerServing: proteinPerServing,
            fatPerServing: fatPerServing, carbsPerServing: carbsPerServing,
            saturatedFatPerServing: saturatedFatPerServing, fiberPerServing: fiberPerServing,
            sugarsPerServing: sugarsPerServing, addedSugarsPerServing: addedSugarsPerServing,
            sodiumPerServing: sodiumPerServing, cholesterolPerServing: cholesterolPerServing,
            secondaryNutrientBackfillState: secondaryNutrientBackfillState, createdAt: createdAt, updatedAt: updatedAt
        )
    }

    var nutritionValues: [Double?] {
        [
            caloriesPerServing, proteinPerServing, fatPerServing, carbsPerServing, gramsPerServing,
            saturatedFatPerServing, fiberPerServing, sugarsPerServing, addedSugarsPerServing,
            sodiumPerServing, cholesterolPerServing
        ]
    }
}

nonisolated struct BackupMealComponent: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var foodItemID: UUID
    var foodSourceIdentifier: String?
    var quantityMode: QuantityMode
    var quantityAmount: Double
    var createdAt: Date
    var updatedAt: Date

    init(_ model: MealComponent) {
        id = model.id
        foodItemID = model.foodItemID
        quantityMode = model.quantityModeKind
        quantityAmount = model.quantityAmount
        createdAt = model.createdAt
        updatedAt = model.updatedAt
    }

    func model(for mealID: UUID) -> MealComponent {
        MealComponent(
            id: id, mealID: mealID, foodItemID: foodItemID,
            quantityMode: quantityMode, quantityAmount: quantityAmount,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

nonisolated struct BackupMeal: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var components: [BackupMealComponent]

    init(id: UUID, name: String, createdAt: Date, updatedAt: Date, components: [BackupMealComponent]) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.components = components.sorted(by: BackupOrdering.before)
    }

    init(_ model: Meal, components: [MealComponent]) {
        self.init(
            id: model.id, name: model.name, createdAt: model.createdAt, updatedAt: model.updatedAt,
            components: components.map(BackupMealComponent.init)
        )
    }

    var model: Meal {
        Meal(id: id, name: name, componentNames: [], createdAt: createdAt, updatedAt: updatedAt)
    }
}

nonisolated struct BackupLogComponentSnapshot: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var mealID: UUID
    var foodItemID: UUID
    var foodSourceIdentifier: String?
    var foodName: String
    var quantityMode: QuantityMode
    var quantityAmount: Double
    var caloriesConsumed: Double
    var proteinConsumed: Double
    var fatConsumed: Double
    var carbsConsumed: Double
    var saturatedFatConsumed: Double?
    var fiberConsumed: Double?
    var sugarsConsumed: Double?
    var addedSugarsConsumed: Double?
    var sodiumConsumed: Double?
    var cholesterolConsumed: Double?
    var createdAt: Date

    init(_ model: LoggedMealComponentSnapshot) {
        id = model.id
        mealID = model.mealID
        foodItemID = model.foodItemID
        foodName = model.foodName
        quantityMode = model.quantityModeKind
        quantityAmount = model.quantityAmount
        caloriesConsumed = model.caloriesConsumed
        proteinConsumed = model.proteinConsumed
        fatConsumed = model.fatConsumed
        carbsConsumed = model.carbsConsumed
        saturatedFatConsumed = model.saturatedFatConsumed
        fiberConsumed = model.fiberConsumed
        sugarsConsumed = model.sugarsConsumed
        addedSugarsConsumed = model.addedSugarsConsumed
        sodiumConsumed = model.sodiumConsumed
        cholesterolConsumed = model.cholesterolConsumed
        createdAt = model.createdAt
    }

    func model(logEntryID: UUID) -> LoggedMealComponentSnapshot {
        LoggedMealComponentSnapshot(
            id: id, logEntryID: logEntryID, mealID: mealID, foodItemID: foodItemID,
            foodName: foodName, quantityMode: quantityMode, quantityAmount: quantityAmount,
            caloriesConsumed: caloriesConsumed, proteinConsumed: proteinConsumed,
            fatConsumed: fatConsumed, carbsConsumed: carbsConsumed,
            saturatedFatConsumed: saturatedFatConsumed, fiberConsumed: fiberConsumed,
            sugarsConsumed: sugarsConsumed, addedSugarsConsumed: addedSugarsConsumed,
            sodiumConsumed: sodiumConsumed, cholesterolConsumed: cholesterolConsumed, createdAt: createdAt
        )
    }

    var nutritionValues: [Double?] {
        [
            quantityAmount, caloriesConsumed, proteinConsumed, fatConsumed, carbsConsumed,
            saturatedFatConsumed, fiberConsumed, sugarsConsumed, addedSugarsConsumed, sodiumConsumed, cholesterolConsumed
        ]
    }
}

nonisolated struct BackupLogEntry: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var foodItemID: UUID?
    var foodSourceIdentifier: String?
    var mealID: UUID?
    var dateLogged: Date
    var foodName: String
    var brand: String?
    var source: FoodSource
    var barcode: String?
    var externalProductID: String?
    var sourceName: String?
    var sourceURL: String?
    var servingDescription: String
    var gramsPerServing: Double?
    var caloriesPerServing: Double
    var proteinPerServing: Double
    var fatPerServing: Double
    var carbsPerServing: Double
    var saturatedFatPerServing: Double?
    var fiberPerServing: Double?
    var sugarsPerServing: Double?
    var addedSugarsPerServing: Double?
    var sodiumPerServing: Double?
    var cholesterolPerServing: Double?
    var quantityMode: QuantityMode
    var servingsConsumed: Double?
    var gramsConsumed: Double?
    var caloriesConsumed: Double
    var proteinConsumed: Double
    var fatConsumed: Double
    var carbsConsumed: Double
    var saturatedFatConsumed: Double?
    var fiberConsumed: Double?
    var sugarsConsumed: Double?
    var addedSugarsConsumed: Double?
    var sodiumConsumed: Double?
    var cholesterolConsumed: Double?
    var secondaryNutrientBackfillState: SecondaryNutrientBackfillState?
    var healthSyncVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var componentSnapshots: [BackupLogComponentSnapshot]

    init(
        id: UUID, foodItemID: UUID?, mealID: UUID?, dateLogged: Date, foodName: String, brand: String?,
        source: FoodSource, barcode: String?, externalProductID: String?, sourceName: String?, sourceURL: String?,
        servingDescription: String, gramsPerServing: Double?, caloriesPerServing: Double,
        proteinPerServing: Double, fatPerServing: Double, carbsPerServing: Double,
        saturatedFatPerServing: Double?, fiberPerServing: Double?, sugarsPerServing: Double?,
        addedSugarsPerServing: Double?, sodiumPerServing: Double?, cholesterolPerServing: Double?,
        quantityMode: QuantityMode, servingsConsumed: Double?, gramsConsumed: Double?,
        caloriesConsumed: Double, proteinConsumed: Double, fatConsumed: Double, carbsConsumed: Double,
        saturatedFatConsumed: Double?, fiberConsumed: Double?, sugarsConsumed: Double?,
        addedSugarsConsumed: Double?, sodiumConsumed: Double?, cholesterolConsumed: Double?,
        secondaryNutrientBackfillState: SecondaryNutrientBackfillState?, healthSyncVersion: Int,
        createdAt: Date, updatedAt: Date, componentSnapshots: [BackupLogComponentSnapshot]
    ) {
        self.id = id
        self.foodItemID = foodItemID
        self.mealID = mealID
        self.dateLogged = dateLogged
        self.foodName = foodName
        self.brand = brand
        self.source = source
        self.barcode = barcode
        self.externalProductID = externalProductID
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.servingDescription = servingDescription
        self.gramsPerServing = gramsPerServing
        self.caloriesPerServing = caloriesPerServing
        self.proteinPerServing = proteinPerServing
        self.fatPerServing = fatPerServing
        self.carbsPerServing = carbsPerServing
        self.saturatedFatPerServing = saturatedFatPerServing
        self.fiberPerServing = fiberPerServing
        self.sugarsPerServing = sugarsPerServing
        self.addedSugarsPerServing = addedSugarsPerServing
        self.sodiumPerServing = sodiumPerServing
        self.cholesterolPerServing = cholesterolPerServing
        self.quantityMode = quantityMode
        self.servingsConsumed = servingsConsumed
        self.gramsConsumed = gramsConsumed
        self.caloriesConsumed = caloriesConsumed
        self.proteinConsumed = proteinConsumed
        self.fatConsumed = fatConsumed
        self.carbsConsumed = carbsConsumed
        self.saturatedFatConsumed = saturatedFatConsumed
        self.fiberConsumed = fiberConsumed
        self.sugarsConsumed = sugarsConsumed
        self.addedSugarsConsumed = addedSugarsConsumed
        self.sodiumConsumed = sodiumConsumed
        self.cholesterolConsumed = cholesterolConsumed
        self.secondaryNutrientBackfillState = secondaryNutrientBackfillState
        self.healthSyncVersion = healthSyncVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.componentSnapshots = componentSnapshots.sorted(by: BackupOrdering.before)
    }

    init(_ model: LogEntry, componentSnapshots: [LoggedMealComponentSnapshot]) {
        self.init(
            id: model.id, foodItemID: model.foodItemID, mealID: model.mealID,
            dateLogged: model.dateLogged, foodName: model.foodName, brand: model.brand,
            source: model.sourceKind, barcode: model.barcode, externalProductID: model.externalProductID,
            sourceName: model.sourceName, sourceURL: model.sourceURL,
            servingDescription: model.servingDescription, gramsPerServing: model.gramsPerServing,
            caloriesPerServing: model.caloriesPerServing, proteinPerServing: model.proteinPerServing,
            fatPerServing: model.fatPerServing, carbsPerServing: model.carbsPerServing,
            saturatedFatPerServing: model.saturatedFatPerServing, fiberPerServing: model.fiberPerServing,
            sugarsPerServing: model.sugarsPerServing, addedSugarsPerServing: model.addedSugarsPerServing,
            sodiumPerServing: model.sodiumPerServing, cholesterolPerServing: model.cholesterolPerServing,
            quantityMode: model.quantityModeKind, servingsConsumed: model.servingsConsumed,
            gramsConsumed: model.gramsConsumed, caloriesConsumed: model.caloriesConsumed,
            proteinConsumed: model.proteinConsumed, fatConsumed: model.fatConsumed, carbsConsumed: model.carbsConsumed,
            saturatedFatConsumed: model.saturatedFatConsumed, fiberConsumed: model.fiberConsumed,
            sugarsConsumed: model.sugarsConsumed, addedSugarsConsumed: model.addedSugarsConsumed,
            sodiumConsumed: model.sodiumConsumed, cholesterolConsumed: model.cholesterolConsumed,
            secondaryNutrientBackfillState: model.secondaryNutrientBackfillState,
            healthSyncVersion: model.healthSyncVersion, createdAt: model.createdAt, updatedAt: model.updatedAt,
            componentSnapshots: componentSnapshots.map(BackupLogComponentSnapshot.init)
        )
    }

    var model: LogEntry {
        LogEntry(
            id: id, foodItemID: foodItemID, mealID: mealID, dateLogged: dateLogged,
            foodName: foodName, brand: brand, source: source, barcode: barcode,
            externalProductID: externalProductID, sourceName: sourceName, sourceURL: sourceURL,
            servingDescription: servingDescription, gramsPerServing: gramsPerServing,
            caloriesPerServing: caloriesPerServing, proteinPerServing: proteinPerServing,
            fatPerServing: fatPerServing, carbsPerServing: carbsPerServing,
            saturatedFatPerServing: saturatedFatPerServing, fiberPerServing: fiberPerServing,
            sugarsPerServing: sugarsPerServing, addedSugarsPerServing: addedSugarsPerServing,
            sodiumPerServing: sodiumPerServing, cholesterolPerServing: cholesterolPerServing,
            quantityMode: quantityMode, servingsConsumed: servingsConsumed, gramsConsumed: gramsConsumed,
            caloriesConsumed: caloriesConsumed, proteinConsumed: proteinConsumed, fatConsumed: fatConsumed,
            carbsConsumed: carbsConsumed, saturatedFatConsumed: saturatedFatConsumed,
            fiberConsumed: fiberConsumed, sugarsConsumed: sugarsConsumed, addedSugarsConsumed: addedSugarsConsumed,
            sodiumConsumed: sodiumConsumed, cholesterolConsumed: cholesterolConsumed,
            secondaryNutrientBackfillState: secondaryNutrientBackfillState,
            healthSyncVersion: healthSyncVersion, createdAt: createdAt, updatedAt: updatedAt
        )
    }

    var nutritionValues: [Double?] {
        [
            gramsPerServing, caloriesPerServing, proteinPerServing, fatPerServing, carbsPerServing,
            saturatedFatPerServing, fiberPerServing, sugarsPerServing, addedSugarsPerServing,
            sodiumPerServing, cholesterolPerServing, servingsConsumed, gramsConsumed,
            caloriesConsumed, proteinConsumed, fatConsumed, carbsConsumed, saturatedFatConsumed,
            fiberConsumed, sugarsConsumed, addedSugarsConsumed, sodiumConsumed, cholesterolConsumed
        ]
    }
}

nonisolated struct BackupWeightEntry: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var day: String
    var recordedAt: Date
    var weightKg: Double
    var source: WeightEntrySource
    var healthKitUUID: String?
    var createdAt: Date
    var updatedAt: Date

    init(_ model: WeightEntry) {
        id = model.id
        day = model.day
        recordedAt = model.recordedAt
        weightKg = model.weightKg
        source = model.source
        healthKitUUID = model.healthKitUUID
        createdAt = model.createdAt
        updatedAt = model.updatedAt
    }

    var model: WeightEntry {
        WeightEntry(
            id: id, day: day, recordedAt: recordedAt, weightKg: weightKg,
            source: source, healthKitUUID: healthKitUUID, createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

nonisolated struct BackupSettings: Codable, Equatable, Sendable {
    var ringColors: MacroRingColorStorage
    var isFoodSuggestionsEnabled: Bool
    var reminders: BackupReminderConfiguration

    static let `default` = BackupSettings(
        ringColors: MacroRingColorStorage(
            proteinHex: MacroRingColorStorage.defaultProteinHex,
            carbHex: MacroRingColorStorage.defaultCarbHex,
            fatHex: MacroRingColorStorage.defaultFatHex
        ),
        isFoodSuggestionsEnabled: true,
        reminders: BackupReminderConfiguration()
    )

    @MainActor static func current(standardDefaults: UserDefaults = .standard, ringDefaults: UserDefaults? = nil) -> Self {
        var reminders = BackupReminderConfiguration()
        reminders.capture(from: standardDefaults)
        let ringDefaults = ringDefaults ?? UserDefaults.macroRingColors
        return Self(
            ringColors: MacroRingColorStorage(
                proteinHex: ringDefaults.string(forKey: AppStorageKeys.customProteinRingColor)
                    ?? MacroRingColorStorage.defaultProteinHex,
                carbHex: ringDefaults.string(forKey: AppStorageKeys.customCarbRingColor)
                    ?? MacroRingColorStorage.defaultCarbHex,
                fatHex: ringDefaults.string(forKey: AppStorageKeys.customFatRingColor)
                    ?? MacroRingColorStorage.defaultFatHex
            ),
            isFoodSuggestionsEnabled: standardDefaults.object(forKey: AppStorageKeys.isFoodSuggestionsEnabled) as? Bool ?? true,
            reminders: reminders
        )
    }

    @MainActor func apply(standardDefaults: UserDefaults = .standard, ringDefaults: UserDefaults? = nil) {
        let ringDefaults = ringDefaults ?? UserDefaults.macroRingColors
        ringDefaults.set(ringColors.proteinHex, forKey: AppStorageKeys.customProteinRingColor)
        ringDefaults.set(ringColors.carbHex, forKey: AppStorageKeys.customCarbRingColor)
        ringDefaults.set(ringColors.fatHex, forKey: AppStorageKeys.customFatRingColor)
        standardDefaults.set(isFoodSuggestionsEnabled, forKey: AppStorageKeys.isFoodSuggestionsEnabled)
        reminders.apply(to: standardDefaults)
    }
}

nonisolated struct BackupReminderConfiguration: Codable, Equatable, Sendable {
    var enabled = false
    var hour = 20
    var minute = 0
    var breakfastEnabled = false
    var breakfastHour = 8
    var breakfastMinute = 0
    var lunchEnabled = false
    var lunchHour = 12
    var lunchMinute = 0
    var dinnerEnabled = false
    var dinnerHour = 18
    var dinnerMinute = 0
    var smartEveningEnabled = false

    @MainActor mutating func capture(from defaults: UserDefaults) {
        enabled = defaults.object(forKey: AppStorageKeys.reminderEnabled) as? Bool ?? false
        hour = defaults.object(forKey: AppStorageKeys.reminderHour) as? Int ?? 20
        minute = defaults.object(forKey: AppStorageKeys.reminderMinute) as? Int ?? 0
        breakfastEnabled = defaults.object(forKey: AppStorageKeys.reminderBreakfastEnabled) as? Bool ?? false
        breakfastHour = defaults.object(forKey: AppStorageKeys.reminderBreakfastHour) as? Int ?? 8
        breakfastMinute = defaults.object(forKey: AppStorageKeys.reminderBreakfastMinute) as? Int ?? 0
        lunchEnabled = defaults.object(forKey: AppStorageKeys.reminderLunchEnabled) as? Bool ?? false
        lunchHour = defaults.object(forKey: AppStorageKeys.reminderLunchHour) as? Int ?? 12
        lunchMinute = defaults.object(forKey: AppStorageKeys.reminderLunchMinute) as? Int ?? 0
        dinnerEnabled = defaults.object(forKey: AppStorageKeys.reminderDinnerEnabled) as? Bool ?? false
        dinnerHour = defaults.object(forKey: AppStorageKeys.reminderDinnerHour) as? Int ?? 18
        dinnerMinute = defaults.object(forKey: AppStorageKeys.reminderDinnerMinute) as? Int ?? 0
        smartEveningEnabled = defaults.object(forKey: AppStorageKeys.reminderSmartEveningEnabled) as? Bool ?? false
    }

    @MainActor func apply(to defaults: UserDefaults) {
        [
            (AppStorageKeys.reminderEnabled, enabled), (AppStorageKeys.reminderBreakfastEnabled, breakfastEnabled),
            (AppStorageKeys.reminderLunchEnabled, lunchEnabled), (AppStorageKeys.reminderDinnerEnabled, dinnerEnabled),
            (AppStorageKeys.reminderSmartEveningEnabled, smartEveningEnabled)
        ].forEach { defaults.set($0.1, forKey: $0.0) }
        [
            (AppStorageKeys.reminderHour, hour), (AppStorageKeys.reminderMinute, minute),
            (AppStorageKeys.reminderBreakfastHour, breakfastHour), (AppStorageKeys.reminderBreakfastMinute, breakfastMinute),
            (AppStorageKeys.reminderLunchHour, lunchHour), (AppStorageKeys.reminderLunchMinute, lunchMinute),
            (AppStorageKeys.reminderDinnerHour, dinnerHour), (AppStorageKeys.reminderDinnerMinute, dinnerMinute)
        ].forEach { defaults.set($0.1, forKey: $0.0) }
    }
}

nonisolated enum BackupOrdering {
    static func before<T: Identifiable>(_ lhs: T, _ rhs: T) -> Bool where T.ID == UUID {
        if let left = (lhs as? any BackupDated)?.backupCreatedAt,
            let right = (rhs as? any BackupDated)?.backupCreatedAt,
            left != right
        {
            return left < right
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

nonisolated private protocol BackupDated {
    var backupCreatedAt: Date { get }
}

extension BackupGoals: BackupDated { fileprivate var backupCreatedAt: Date { createdAt } }
extension BackupBodyProfile: BackupDated { fileprivate var backupCreatedAt: Date { createdAt } }
extension BackupFood: BackupDated { fileprivate var backupCreatedAt: Date { createdAt } }
extension BackupMealComponent: BackupDated { fileprivate var backupCreatedAt: Date { createdAt } }
extension BackupMeal: BackupDated { fileprivate var backupCreatedAt: Date { createdAt } }
extension BackupLogEntry: BackupDated { fileprivate var backupCreatedAt: Date { createdAt } }
extension BackupLogComponentSnapshot: BackupDated { fileprivate var backupCreatedAt: Date { createdAt } }
extension BackupWeightEntry: BackupDated { fileprivate var backupCreatedAt: Date { createdAt } }
