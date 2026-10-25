import Foundation
import SwiftData

@MainActor
struct WeightRepository {
    let modelContext: ModelContext

    func entries(in range: Range<Date>? = nil) throws -> [WeightEntry] {
        let all = try modelContext.fetch(FetchDescriptor<WeightEntry>())
        return all.filter { entry in
            guard let range else { return true }
            return range.contains(entry.recordedAt)
        }.sorted {
            if $0.recordedAt != $1.recordedAt { return $0.recordedAt > $1.recordedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func upsertManual(weightKg: Double, day: Date, calendar: Calendar = .current) throws {
        guard weightKg.isFinite, weightKg > 0 else { return }
        let dayKey = CalendarDay(date: day, calendar: calendar).sharingDayKey
        try PersistenceReporter.persist(modelContext: modelContext, operation: "weight.manual.save") {
            let entries = try modelContext.fetch(FetchDescriptor<WeightEntry>())
            let existing = entries.first { $0.source == .manual && $0.day == dayKey }
            let entry = existing ?? WeightEntry(day: dayKey, recordedAt: day, weightKg: weightKg)
            entry.recordedAt = day
            entry.weightKg = weightKg
            entry.updatedAt = .now
            if existing == nil { modelContext.insert(entry) }

            if let profile = try BodyProfileRepository.activeProfile(modelContext: modelContext) {
                profile.weightKg = weightKg
                profile.updatedAt = .now
            } else {
                modelContext.insert(BodyProfile(weightKg: weightKg))
            }
        }
    }

    func delete(_ entry: WeightEntry) throws {
        let id = entry.persistentModelID
        try PersistenceReporter.persist(modelContext: modelContext, operation: "weight.delete") {
            if let stored = modelContext.model(for: id) as? WeightEntry {
                modelContext.delete(stored)
            }
        }
    }

    func latest() throws -> WeightEntry? {
        try entries().first
    }

    func applyHealthChanges(_ samples: [HealthWeightSample], deletedUUIDs: [String]) throws {
        guard !samples.isEmpty || !deletedUUIDs.isEmpty else { return }
        try PersistenceReporter.persist(modelContext: modelContext, operation: "weight.health.import") {
            let entries = try modelContext.fetch(FetchDescriptor<WeightEntry>())
            let deletedIDs = Set(deletedUUIDs)
            for entry in entries where entry.source == .healthKit && entry.healthKitUUID.map(deletedIDs.contains) == true {
                modelContext.delete(entry)
            }

            let latestSamples = Dictionary(grouping: samples.filter { $0.kilograms.isFinite && $0.kilograms > 0 }) {
                CalendarDay(date: $0.date).sharingDayKey
            }.values.compactMap { samples in
                samples.max {
                    if $0.date != $1.date { return $0.date < $1.date }
                    return $0.uuid < $1.uuid
                }
            }
            for sample in latestSamples {
                let day = CalendarDay(date: sample.date).sharingDayKey
                let existing =
                    entries.first {
                        $0.source == .healthKit && $0.healthKitUUID == sample.uuid && !deletedIDs.contains(sample.uuid)
                    }
                    ?? entries.first {
                        $0.source == .healthKit && $0.day == day && $0.healthKitUUID.map { !deletedIDs.contains($0) } == true
                    }
                if let existing {
                    guard sample.uuid == existing.healthKitUUID || sample.date >= existing.recordedAt else { continue }
                    existing.day = day
                    existing.recordedAt = sample.date
                    existing.weightKg = sample.kilograms
                    existing.healthKitUUID = sample.uuid
                    existing.updatedAt = .now
                } else {
                    modelContext.insert(
                        WeightEntry(
                            day: day,
                            recordedAt: sample.date,
                            weightKg: sample.kilograms,
                            source: .healthKit,
                            healthKitUUID: sample.uuid
                        )
                    )
                }
            }

            let healthEntries = try modelContext.fetch(FetchDescriptor<WeightEntry>())
                .filter { $0.source == .healthKit }
            for sameDay in Dictionary(grouping: healthEntries, by: \.day).values where sameDay.count > 1 {
                let latest = sameDay.max { $0.recordedAt < $1.recordedAt }
                for entry in sameDay where entry !== latest {
                    modelContext.delete(entry)
                }
            }
        }
    }
}

struct HealthWeightSample: Sendable {
    let uuid: String
    let date: Date
    let kilograms: Double
}
