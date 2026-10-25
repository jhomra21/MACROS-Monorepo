import Foundation
import SwiftData

enum GoalSex: String, CaseIterable, Identifiable, Hashable {
    case female
    case male
    case unspecified

    var id: String { rawValue }

}

enum GoalActivityLevel: String, CaseIterable, Identifiable, Hashable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive

    var id: String { rawValue }

}

enum GoalMacroPreset: String, CaseIterable, Identifiable, Hashable {
    case balanced
    case highProtein
    case lowCarb
    case custom

    var id: String { rawValue }

}

enum GoalUnitSystem: String, CaseIterable, Identifiable, Hashable {
    case metric
    case imperial

    var id: String { rawValue }
}

@Model
final class BodyProfile {
    var id: UUID = UUID()
    var sexRaw: String = GoalSex.unspecified.rawValue
    var birthYear: Int?
    var heightCm: Double?
    var weightKg: Double?
    var activityLevelRaw: String = GoalActivityLevel.moderate.rawValue
    var goalCalorieOffset: Double = 0
    var macroPresetRaw: String = GoalMacroPreset.balanced.rawValue
    var unitSystemRaw: String = GoalUnitSystem.metric.rawValue
    var createdAt: Date = Foundation.Date()
    var updatedAt: Date = Foundation.Date()

    init(
        id: UUID = UUID(),
        sex: GoalSex = .unspecified,
        birthYear: Int? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        activityLevel: GoalActivityLevel = .moderate,
        goalCalorieOffset: Double = 0,
        macroPreset: GoalMacroPreset = .balanced,
        unitSystem: GoalUnitSystem = .metric,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        sexRaw = sex.rawValue
        self.birthYear = birthYear
        self.heightCm = heightCm
        self.weightKg = weightKg
        activityLevelRaw = activityLevel.rawValue
        self.goalCalorieOffset = goalCalorieOffset
        macroPresetRaw = macroPreset.rawValue
        unitSystemRaw = unitSystem.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var sex: GoalSex {
        get { GoalSex(rawValue: sexRaw) ?? .unspecified }
        set { sexRaw = newValue.rawValue }
    }

    var activityLevel: GoalActivityLevel {
        get { GoalActivityLevel(rawValue: activityLevelRaw) ?? .moderate }
        set { activityLevelRaw = newValue.rawValue }
    }

    var macroPreset: GoalMacroPreset {
        get { GoalMacroPreset(rawValue: macroPresetRaw) ?? .balanced }
        set { macroPresetRaw = newValue.rawValue }
    }

    var unitSystem: GoalUnitSystem {
        get { GoalUnitSystem(rawValue: unitSystemRaw) ?? .metric }
        set { unitSystemRaw = newValue.rawValue }
    }
}

extension BodyProfile {
    static func activeRecord(from profiles: [BodyProfile]) -> BodyProfile? {
        profiles.max { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
            return lhs.createdAt < rhs.createdAt
        }
    }
}
