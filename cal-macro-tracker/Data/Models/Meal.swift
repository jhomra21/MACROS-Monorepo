import Foundation
import SwiftData

@Model
final class Meal {
    var id: UUID
    var name: String
    var searchableText: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        componentNames: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.searchableText = Meal.makeSearchableText(name: name, componentNames: componentNames)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func normalizeForPersistence(componentNames: [String]) {
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updateSearchableText(componentNames: componentNames)
    }

    func updateSearchableText(componentNames: [String], updateTimestamp: Bool = true) {
        searchableText = Meal.makeSearchableText(name: name, componentNames: componentNames)
        if updateTimestamp {
            updatedAt = .now
        }
    }

    static func makeSearchableText(name: String, componentNames: [String]) -> String {
        var seen = Set<String>()
        return ([name] + componentNames)
            .compactMap(normalizedSearchValue)
            .filter { seen.insert($0).inserted }
            .joined(separator: " ")
    }

    private static func normalizedSearchValue(_ value: String?) -> String? {
        TextNormalization.normalizedSearchText(value)
    }
}

struct MealSearchQuery: Hashable {
    let normalizedText: String
    let tokens: Set<String>

    init(_ query: String) {
        let normalizedText = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.normalizedText = normalizedText
        tokens = Set(normalizedText.split(whereSeparator: { $0.isWhitespace }).map(String.init))
    }

    var isEmpty: Bool {
        normalizedText.isEmpty
    }
}

enum MealLocalSearch {
    static func rank(for meal: Meal, matching query: MealSearchQuery) -> Int? {
        let name = meal.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if name == query.normalizedText {
            return 0
        }

        if name.hasPrefix(query.normalizedText) {
            return 1
        }

        let isTextMatch = meal.searchableText.contains(query.normalizedText)
        let searchableTokens = Set(meal.searchableText.split(whereSeparator: { $0.isWhitespace }).map(String.init))
        if query.tokens.isSubset(of: searchableTokens) {
            return 2
        }

        return isTextMatch ? 3 : nil
    }
}
