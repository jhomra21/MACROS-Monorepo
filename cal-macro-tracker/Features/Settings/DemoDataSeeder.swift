#if DEBUG
import Foundation
import SwiftData

/// Replaces local data with a fixed sample dataset for App Store captures. DEBUG builds only.
@MainActor
enum DemoDataSeeder {
    static func seed(into container: ModelContainer, now: Date = .now) async throws {
        try await BackupImporter.apply(makeBackup(now: now), to: container, mode: .replace)
        UserDefaults.standard.set(true, forKey: AppStorageKeys.hasCompletedGoalSetup)
        UserDefaults.standard.set(true, forKey: AppStorageKeys.hasCompletedDashboardTutorial)
        WidgetTimelineReloader.reloadMacroWidgets()
        NotificationCenter.default.post(name: .remindersDidChange, object: nil)
    }

    static func makeBackup(now: Date) throws -> MACROSBackup {
        let weights = try weightEntries(now: now)
        let profile = BodyProfile(
            sex: .male,
            birthYear: Calendar.current.component(.year, from: now) - 34,
            heightCm: 177.8,
            weightKg: weights.last?.weightKg,
            activityLevel: .moderate,
            macroPreset: .balanced,
            unitSystem: .imperial,
            createdAt: now,
            updatedAt: now
        )
        let goals = DailyGoals(
            calorieGoal: 2_200, proteinGoalGrams: 150, fatGoalGrams: 70, carbGoalGrams: 240,
            createdAt: now, updatedAt: now
        )
        return MACROSBackup(
            version: 1,
            exportedAt: now,
            appVersion: "demo",
            goals: [BackupGoals(goals)],
            bodyProfile: [BackupBodyProfile(profile)],
            foods: DemoFoods.all.map { BackupFood($0.foodItem(now: now)) },
            meals: [],
            logEntries: todayEntries(now: now) + pastEntries(now: now),
            weightEntries: weights,
            settings: .default
        )
    }

    private static func todayEntries(now: Date) -> [BackupLogEntry] {
        [
            logEntry(DemoFoods.oatmeal, servings: 1, at: date(daysAgo: 0, hour: 7, minute: 30, now: now)),
            logEntry(DemoFoods.greekYogurt, servings: 1, at: date(daysAgo: 0, hour: 10, minute: 0, now: now)),
            logEntry(DemoFoods.chickenBowl, servings: 1, at: date(daysAgo: 0, hour: 12, minute: 45, now: now)),
            logEntry(DemoFoods.proteinBar, servings: 1, at: date(daysAgo: 0, hour: 15, minute: 30, now: now))
        ]
    }

    private static func pastEntries(now: Date) -> [BackupLogEntry] {
        (1...89).flatMap { daysAgo -> [BackupLogEntry] in
            let portions = lightDays.contains(daysAgo) ? DemoDays.light : DemoDays.rotation[daysAgo % DemoDays.rotation.count]
            return portions.enumerated().map { index, portion in
                let slot = slotTimes[index]
                let at = date(daysAgo: daysAgo, hour: slot.hour, minute: slot.minute, now: now)
                return logEntry(portion.food, servings: portion.servings, at: at)
            }
        }
    }

    /// Weights in pounds, oldest first. Stored as kilograms; the imperial profile shows pounds.
    private static let weightPounds: [Double] = [
        182.4, 182.1, 182.3, 181.8, 181.9, 181.4, 181.6, 181.1, 181.3, 180.9,
        181.0, 180.7, 180.9, 180.5, 180.8, 180.6, 180.7, 180.5, 180.8, 180.6
    ]

    private static func weightEntries(now: Date) throws -> [BackupWeightEntry] {
        try weightPounds.enumerated().map { index, pounds in
            // Every 3 days, from 58 days ago through yesterday.
            let recordedAt = date(daysAgo: 58 - 3 * index, hour: 7, minute: 0, now: now)
            let kilograms = try GoalCalculator.kg(fromPounds: pounds)
            return BackupWeightEntry(
                WeightEntry(
                    day: CalendarDay(date: recordedAt).sharingDayKey,
                    recordedAt: recordedAt,
                    weightKg: kilograms,
                    createdAt: recordedAt,
                    updatedAt: recordedAt
                ))
        }
    }

    private static let lightDays: Set<Int> = [9, 31, 58]
    private static let slotTimes: [(hour: Int, minute: Int)] = [(7, 30), (10, 0), (12, 45), (15, 30), (19, 0)]

    private static func logEntry(_ food: DemoFood, servings: Double, at date: Date) -> BackupLogEntry {
        BackupLogEntry(
            LogEntry(
                foodItemID: food.id,
                dateLogged: date,
                foodName: food.name,
                source: .custom,
                servingDescription: food.serving,
                gramsPerServing: food.grams,
                caloriesPerServing: food.kcal,
                proteinPerServing: food.protein,
                fatPerServing: food.fat,
                carbsPerServing: food.carbs,
                quantityMode: .servings,
                servingsConsumed: servings,
                caloriesConsumed: food.kcal * servings,
                proteinConsumed: food.protein * servings,
                fatConsumed: food.fat * servings,
                carbsConsumed: food.carbs * servings,
                createdAt: date,
                updatedAt: date
            ),
            componentSnapshots: []
        )
    }

    private static func date(daysAgo: Int, hour: Int, minute: Int, now: Date) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}

/// Per-serving nutrition. `slot` fixes the UUID so every run produces identical rows.
private struct DemoFood {
    let slot: Int
    let name: String
    let serving: String
    let grams: Double
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    var id: UUID {
        UUID(uuidString: "00000000-0000-4000-8000-\(String(format: "%012d", slot))") ?? UUID()
    }

    func foodItem(now: Date) -> FoodItem {
        FoodItem(
            id: id, name: name, source: .custom, servingDescription: serving, gramsPerServing: grams,
            caloriesPerServing: kcal, proteinPerServing: protein, fatPerServing: fat, carbsPerServing: carbs,
            createdAt: now, updatedAt: now
        )
    }
}

private enum DemoFoods {
    static let oatmeal = DemoFood(
        slot: 1, name: "Oatmeal with banana", serving: "1 bowl", grams: 250, kcal: 350, protein: 12, carbs: 62, fat: 7)
    static let greekYogurt = DemoFood(
        slot: 2, name: "Plain Greek yogurt cup", serving: "1 cup", grams: 170, kcal: 150, protein: 15, carbs: 8, fat: 6)
    static let chickenBowl = DemoFood(
        slot: 3, name: "Chicken and rice bowl", serving: "1 bowl", grams: 400, kcal: 600, protein: 48, carbs: 70, fat: 14)
    static let proteinBar = DemoFood(
        slot: 4, name: "Protein bar", serving: "1 bar", grams: 60, kcal: 210, protein: 20, carbs: 22, fat: 7)
    static let scrambledEggs = DemoFood(
        slot: 5, name: "Scrambled eggs", serving: "2 eggs", grams: 130, kcal: 180, protein: 13, carbs: 2, fat: 13)
    static let wholeWheatToast = DemoFood(
        slot: 6, name: "Whole wheat toast", serving: "1 slice", grams: 35, kcal: 90, protein: 4, carbs: 15, fat: 1)
    static let apple = DemoFood(
        slot: 7, name: "Apple", serving: "1 medium", grams: 182, kcal: 95, protein: 0, carbs: 25, fat: 0)
    static let almonds = DemoFood(
        slot: 8, name: "Almonds", serving: "1 oz", grams: 28, kcal: 165, protein: 6, carbs: 6, fat: 14)
    static let salmon = DemoFood(
        slot: 9, name: "Salmon fillet", serving: "4 oz", grams: 113, kcal: 230, protein: 25, carbs: 0, fat: 14)
    static let brownRice = DemoFood(
        slot: 10, name: "Brown rice", serving: "1 cup cooked", grams: 195, kcal: 215, protein: 5, carbs: 45, fat: 2)
    static let mixedSalad = DemoFood(
        slot: 11, name: "Mixed salad", serving: "2 cups", grams: 100, kcal: 35, protein: 2, carbs: 7, fat: 0)
    static let turkeySandwich = DemoFood(
        slot: 12, name: "Turkey sandwich", serving: "1 sandwich", grams: 200, kcal: 390, protein: 26, carbs: 42, fat: 12)
    static let banana = DemoFood(
        slot: 13, name: "Banana", serving: "1 medium", grams: 118, kcal: 105, protein: 1, carbs: 27, fat: 0)
    static let cottageCheese = DemoFood(
        slot: 14, name: "Cottage cheese", serving: "1/2 cup", grams: 113, kcal: 110, protein: 13, carbs: 4, fat: 5)
    static let pasta = DemoFood(
        slot: 15, name: "Pasta with tomato sauce", serving: "1 cup", grams: 250, kcal: 280, protein: 9, carbs: 52, fat: 4)
    static let blackBeans = DemoFood(
        slot: 16, name: "Black beans", serving: "1/2 cup", grams: 86, kcal: 115, protein: 8, carbs: 20, fat: 0.5)
    static let sweetPotato = DemoFood(
        slot: 17, name: "Sweet potato", serving: "1 medium", grams: 114, kcal: 100, protein: 2, carbs: 23, fat: 0)
    static let peanutButter = DemoFood(
        slot: 18, name: "Peanut butter", serving: "1 tbsp", grams: 16, kcal: 95, protein: 4, carbs: 3, fat: 8)
    static let orange = DemoFood(
        slot: 19, name: "Orange", serving: "1 medium", grams: 131, kcal: 62, protein: 1, carbs: 15, fat: 0)
    static let riceCakes = DemoFood(
        slot: 20, name: "Rice cakes", serving: "2 cakes", grams: 18, kcal: 70, protein: 1, carbs: 15, fat: 0.5)

    static let all: [DemoFood] = [
        oatmeal, greekYogurt, chickenBowl, proteinBar, scrambledEggs, wholeWheatToast, apple, almonds, salmon,
        brownRice, mixedSalad, turkeySandwich, banana, cottageCheese, pasta, blackBeans, sweetPotato, peanutButter,
        orange, riceCakes
    ]
}

private typealias DemoPortion = (food: DemoFood, servings: Double)

/// Rotating day patterns. Each rotation day totals 1,925 to 2,230 kcal. The light pattern totals 1,325 kcal.
private enum DemoDays {
    static let rotation: [[DemoPortion]] = [
        [(DemoFoods.oatmeal, 1), (DemoFoods.turkeySandwich, 1), (DemoFoods.chickenBowl, 1), (DemoFoods.almonds, 1), (DemoFoods.pasta, 2)],
        [(DemoFoods.chickenBowl, 1), (DemoFoods.pasta, 2), (DemoFoods.salmon, 2), (DemoFoods.turkeySandwich, 1)],
        [
            (DemoFoods.oatmeal, 1), (DemoFoods.salmon, 2), (DemoFoods.chickenBowl, 1), (DemoFoods.brownRice, 2),
            (DemoFoods.turkeySandwich, 1)
        ],
        [
            (DemoFoods.chickenBowl, 1), (DemoFoods.turkeySandwich, 1), (DemoFoods.pasta, 2), (DemoFoods.proteinBar, 1),
            (DemoFoods.almonds, 1)
        ],
        [(DemoFoods.oatmeal, 1), (DemoFoods.chickenBowl, 1), (DemoFoods.salmon, 2), (DemoFoods.brownRice, 2), (DemoFoods.pasta, 1)],
        [
            (DemoFoods.turkeySandwich, 1), (DemoFoods.chickenBowl, 1), (DemoFoods.pasta, 2), (DemoFoods.proteinBar, 1),
            (DemoFoods.brownRice, 2)
        ]
    ]

    static let light: [DemoPortion] = [(DemoFoods.oatmeal, 1), (DemoFoods.chickenBowl, 1), (DemoFoods.pasta, 1), (DemoFoods.apple, 1)]
}
#endif
