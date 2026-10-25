import Foundation
import SwiftData

@MainActor
struct BodyProfileRepository {
    let modelContext: ModelContext

    static func activeProfile(modelContext: ModelContext) throws -> BodyProfile? {
        BodyProfile.activeRecord(from: try modelContext.fetch(FetchDescriptor<BodyProfile>()))
    }

    func save(_ profile: BodyProfile, operation: String) throws {
        try PersistenceReporter.persist(modelContext: modelContext, operation: operation) {
            let profiles = try modelContext.fetch(FetchDescriptor<BodyProfile>())
            let savedProfile = BodyProfile.activeRecord(from: profiles)
            let destination = savedProfile ?? profile
            if savedProfile == nil {
                modelContext.insert(destination)
            }

            destination.sex = profile.sex
            destination.birthYear = profile.birthYear
            destination.heightCm = profile.heightCm
            destination.weightKg = profile.weightKg
            destination.activityLevel = profile.activityLevel
            destination.goalCalorieOffset = profile.goalCalorieOffset
            destination.macroPreset = profile.macroPreset
            destination.unitSystem = profile.unitSystem
            destination.updatedAt = Date.now
        }
    }
}
