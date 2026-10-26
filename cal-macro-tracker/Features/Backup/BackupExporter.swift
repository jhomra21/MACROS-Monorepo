import Foundation
import SwiftData

@MainActor
enum BackupExporter {
    static func makeBackup(
        from context: ModelContext,
        exportedAt: Date = .now,
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
        settings: BackupSettings? = nil
    ) throws -> MACROSBackup {
        let foods = try context.fetch(FetchDescriptor<FoodItem>())
            .filter { $0.sourceKind != .common }
            .map(BackupFood.init)
            .sorted(by: BackupOrdering.before)
        let meals = try context.fetch(FetchDescriptor<Meal>())
        let mealComponents = try context.fetch(FetchDescriptor<MealComponent>())
        let componentsByMeal = Dictionary(grouping: mealComponents, by: \.mealID)
        let backupMeals = meals.map { BackupMeal($0, components: componentsByMeal[$0.id] ?? []) }
            .sorted(by: BackupOrdering.before)

        let snapshots = try context.fetch(FetchDescriptor<LoggedMealComponentSnapshot>())
        let snapshotsByEntry = Dictionary(grouping: snapshots, by: \.logEntryID)
        let entries = try context.fetch(FetchDescriptor<LogEntry>())
            .map { BackupLogEntry($0, componentSnapshots: snapshotsByEntry[$0.id] ?? []) }
            .sorted(by: BackupOrdering.before)

        return MACROSBackup(
            version: 1,
            exportedAt: exportedAt,
            appVersion: appVersion,
            goals: try context.fetch(FetchDescriptor<DailyGoals>()).map(BackupGoals.init).sorted(by: BackupOrdering.before),
            bodyProfile: try context.fetch(FetchDescriptor<BodyProfile>())
                .map(BackupBodyProfile.init).sorted(by: BackupOrdering.before),
            foods: foods,
            meals: backupMeals,
            logEntries: entries,
            weightEntries: try context.fetch(FetchDescriptor<WeightEntry>())
                .map(BackupWeightEntry.init).sorted(by: BackupOrdering.before),
            settings: settings ?? .current()
        )
    }

    static func encode(_ backup: MACROSBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(BackupDateCodec.string(from: date))
        }
        return try encoder.encode(backup)
    }

    static func csv(for entries: [LogEntry]) -> String {
        let rows = entries.sorted {
            if $0.dateLogged != $1.dateLogged { return $0.dateLogged < $1.dateLogged }
            return $0.id.uuidString < $1.id.uuidString
        }
        let header = [
            "date", "food_or_meal_name", "servings_consumed", "grams_consumed",
            "calories_consumed", "protein_consumed", "carbs_consumed", "fat_consumed",
            "calories_per_serving", "protein_per_serving", "carbs_per_serving", "fat_per_serving"
        ]
        let lines: [String] = rows.map { entry -> String in
            let cells: [String] = [
                dateString(entry.dateLogged),
                entry.foodName,
                entry.servingsConsumed.map { String($0) } ?? "",
                entry.gramsConsumed.map { String($0) } ?? "",
                String(entry.caloriesConsumed), String(entry.proteinConsumed),
                String(entry.carbsConsumed), String(entry.fatConsumed),
                String(entry.caloriesPerServing), String(entry.proteinPerServing),
                String(entry.carbsPerServing), String(entry.fatPerServing)
            ]
            return cells.map { csvCell($0) }.joined(separator: ",")
        }
        return ([header.joined(separator: ",")] + lines).joined(separator: "\r\n")
    }

    private static func csvCell(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

nonisolated enum BackupDateCodec {
    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}
