import Foundation

nonisolated enum MealPhotoHiddenFatAnswer: String, Encodable, Sendable {
    case yes, no, skipped
}

/// Accuracy numbers only: counts and one percentage. No food names, no install ID, no photo.
nonisolated struct MealPhotoFeedback: Encodable, Equatable, Sendable {
    let requestId: String
    let model: String
    let suggested: Int
    let keptUnchanged: Int
    let gramsEdited: Int
    let medianGramChangePct: Double?
    let removed: Int
    let added: Int
    let hiddenFatAnswer: MealPhotoHiddenFatAnswer

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(requestId, forKey: .requestId)
        try container.encode(model, forKey: .model)
        try container.encode(suggested, forKey: .suggested)
        try container.encode(keptUnchanged, forKey: .keptUnchanged)
        try container.encode(gramsEdited, forKey: .gramsEdited)
        // The contract wants an explicit null when nothing was edited.
        try container.encode(medianGramChangePct, forKey: .medianGramChangePct)
        try container.encode(removed, forKey: .removed)
        try container.encode(added, forKey: .added)
        try container.encode(hiddenFatAnswer, forKey: .hiddenFatAnswer)
    }

    private enum CodingKeys: String, CodingKey {
        case requestId, model, suggested, keptUnchanged, gramsEdited, medianGramChangePct, removed, added, hiddenFatAnswer
    }
}

extension MealPhotoFeedback {
    static let maximumChangePct = 1_000.0

    /// Compares what the model suggested with what the user logged. Matching a different food is not counted.
    static func make(
        requestID: String,
        model: String,
        suggested: [MealPhotoSuggestedFood],
        final: [MealPhotoItem],
        hiddenFatAnswer: MealPhotoHiddenFatAnswer
    ) -> MealPhotoFeedback {
        let finalBySuggestionID = Dictionary(final.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var kept = 0
        var edited = 0
        var removed = 0
        var changes: [Double] = []
        for food in suggested {
            guard let item = finalBySuggestionID[food.id] else {
                removed += 1
                continue
            }
            if let before = food.grams, let after = item.gramsEaten, abs(before - after) < 0.05 {
                kept += 1
                continue
            }
            edited += 1
            if let before = food.grams, let after = item.gramsEaten {
                changes.append(min(abs(after - before) / before * 100, maximumChangePct))
            }
        }
        return MealPhotoFeedback(
            requestId: requestID,
            model: model,
            suggested: suggested.count,
            keptUnchanged: kept,
            gramsEdited: edited,
            medianGramChangePct: median(changes).map { ($0 * 10).rounded() / 10 },
            removed: removed,
            added: final.filter { $0.origin == .added }.count,
            hiddenFatAnswer: hiddenFatAnswer
        )
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
