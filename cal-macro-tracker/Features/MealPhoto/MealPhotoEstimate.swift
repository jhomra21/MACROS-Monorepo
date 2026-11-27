import Foundation

/// A validated meal photo estimate. The model only names foods and weights; nutrition always comes from matched food data.
nonisolated struct MealPhotoEstimate: Equatable, Sendable {
    enum Status: String, Sendable {
        case ok
        case notFood = "not_food"
        case unclear
        case packaged
    }

    let requestID: String
    let model: String
    let status: Status
    let foods: [MealPhotoSuggestedFood]
}

nonisolated struct MealPhotoSuggestedFood: Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let grams: Double?
    let preparation: String?
    let hiddenFatLikely: Bool
    let volumeMl: Double?

    init(
        id: UUID = UUID(), name: String, grams: Double?, preparation: String? = nil,
        hiddenFatLikely: Bool = false, volumeMl: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.grams = grams
        self.preparation = preparation
        self.hiddenFatLikely = hiddenFatLikely
        self.volumeMl = volumeMl
    }
}

/// Parses and sanitizes the Worker response. Malformed foods are dropped instead of failing the whole scan.
nonisolated enum MealPhotoResponseParser {
    static let maximumFoods = 15
    static let maximumGrams = 3_000.0
    static let maximumNameLength = 80

    enum ParseError: Error { case invalidResponse }

    private struct Raw: Decodable {
        let requestId: String?
        let model: String?
        let status: String?
        let foods: [RawFood]?
    }

    private struct RawFood: Decodable {
        let name: String?
        let grams: Double?
        let preparation: String?
        let hiddenFatLikely: Bool?
        let volumeMl: Double?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)
            name = try? container.decode(String.self, forKey: .name)
            grams = try? container.decode(Double.self, forKey: .grams)
            preparation = try? container.decode(String.self, forKey: .preparation)
            hiddenFatLikely = try? container.decode(Bool.self, forKey: .hiddenFatLikely)
            volumeMl = try? container.decode(Double.self, forKey: .volumeMl)
        }

        private enum Key: String, CodingKey { case name, grams, preparation, hiddenFatLikely, volumeMl }
    }

    static func parse(_ data: Data) throws -> MealPhotoEstimate {
        guard let raw = try? JSONDecoder().decode(Raw.self, from: data),
            let requestID = raw.requestId, !requestID.isEmpty,
            let model = raw.model,
            let status = raw.status.flatMap(MealPhotoEstimate.Status.init(rawValue:))
        else { throw ParseError.invalidResponse }
        let foods = status == .ok ? (raw.foods ?? []).compactMap(sanitized).prefix(maximumFoods) : []
        return MealPhotoEstimate(requestID: requestID, model: model, status: status, foods: Array(foods))
    }

    private static func sanitized(_ raw: RawFood) -> MealPhotoSuggestedFood? {
        guard let name = raw.name?.trimmingCharacters(in: .whitespacesAndNewlines),
            !name.isEmpty, name.count <= maximumNameLength
        else { return nil }
        // A zero or non-finite weight is not a usable estimate; the user is asked for a quantity instead.
        let grams = raw.grams.flatMap { $0.isFinite && $0 > 0 ? min($0, maximumGrams) : nil }
        let volumeMl = raw.volumeMl.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        return MealPhotoSuggestedFood(
            name: name,
            grams: grams,
            preparation: raw.preparation.flatMap(TextNormalization.trimmedNonEmpty),
            hiddenFatLikely: raw.hiddenFatLikely ?? false,
            volumeMl: volumeMl
        )
    }
}
