import Foundation
import SwiftData

enum WeightEntrySource: String, Codable {
    case manual
    case healthKit
}

@Model
final class WeightEntry {
    var id: UUID = UUID()
    var day: String = ""
    var recordedAt: Date = Foundation.Date.now
    var weightKg: Double = 0
    var sourceRaw: String = WeightEntrySource.manual.rawValue
    var healthKitUUID: String?
    var createdAt: Date = Foundation.Date.now
    var updatedAt: Date = Foundation.Date.now

    init(
        id: UUID = UUID(),
        day: String,
        recordedAt: Date,
        weightKg: Double,
        source: WeightEntrySource = .manual,
        healthKitUUID: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.day = day
        self.recordedAt = recordedAt
        self.weightKg = weightKg
        sourceRaw = source.rawValue
        self.healthKitUUID = healthKitUUID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var source: WeightEntrySource {
        get { WeightEntrySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}
