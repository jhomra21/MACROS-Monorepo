import Foundation
import SwiftData

@MainActor
struct SharingUploadCoordinator {
    func payload(
        container: ModelContainer,
        date: Date,
        calendar: Calendar,
        includeFoods: Bool
    ) throws -> SharingDailySnapshotPayload {
        let localSnapshot = try DailyMacroSnapshotLoader.loadNutrition(for: date, in: container, calendar: calendar)
        let context = ModelContext(container)
        let currentGoals = MacroGoalsSnapshot(
            goals: DailyGoals.activeRecord(from: try context.fetch(FetchDescriptor<DailyGoals>()))
        )
        let foods: [SharedFoodPayload]?
        if includeFoods {
            let entries = try context.fetch(LogEntryQuery.descriptor(for: CalendarDay(date: date, calendar: calendar)))
                .sorted {
                    $0.dateLogged == $1.dateLogged
                        ? $0.id.uuidString < $1.id.uuidString
                        : $0.dateLogged < $1.dateLogged
                }
            // Share the first 100 entries in dashboard sort order.
            foods = entries.prefix(100).enumerated().map { SharedFoodPayload(entry: $0.element, sortIndex: $0.offset) }
        } else {
            foods = nil
        }

        return SharingDailySnapshotPayload(
            day: CalendarDay(date: date, calendar: calendar).sharingDayKey,
            timeZoneId: calendar.timeZone.identifier,
            calories: localSnapshot.totals.calories,
            protein: localSnapshot.totals.protein,
            fat: localSnapshot.totals.fat,
            carbs: localSnapshot.totals.carbs,
            entryCount: localSnapshot.entryCount,
            foods: foods,
            calorieGoal: currentGoals.calorieGoal,
            proteinGoal: currentGoals.proteinGoalGrams,
            carbsGoal: currentGoals.carbGoalGrams,
            fatGoal: currentGoals.fatGoalGrams
        )
    }
}
