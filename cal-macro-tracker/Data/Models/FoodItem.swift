import Foundation
import SwiftData

@Model
final class FoodItem {
    var id: UUID
    var name: String
    var brand: String?
    var source: String
    var barcode: String?
    var externalProductID: String?
    var sourceName: String?
    var sourceURL: String?
    var servingDescription: String
    var gramsPerServing: Double?
    var caloriesPerServing: Double
    var proteinPerServing: Double
    var fatPerServing: Double
    var carbsPerServing: Double
    var saturatedFatPerServing: Double?
    var fiberPerServing: Double?
    var sugarsPerServing: Double?
    var addedSugarsPerServing: Double?
    var sodiumPerServing: Double?
    var cholesterolPerServing: Double?
    var secondaryNutrientBackfillStateRaw: String?
    var searchableText: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        source: FoodSource,
        barcode: String? = nil,
        externalProductID: String? = nil,
        sourceName: String? = nil,
        sourceURL: String? = nil,
        servingDescription: String,
        gramsPerServing: Double? = nil,
        caloriesPerServing: Double,
        proteinPerServing: Double,
        fatPerServing: Double,
        carbsPerServing: Double,
        saturatedFatPerServing: Double? = nil,
        fiberPerServing: Double? = nil,
        sugarsPerServing: Double? = nil,
        addedSugarsPerServing: Double? = nil,
        sodiumPerServing: Double? = nil,
        cholesterolPerServing: Double? = nil,
        secondaryNutrientBackfillState: SecondaryNutrientBackfillState? = .current,
        aliases: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.source = source.rawValue
        self.barcode = barcode
        self.externalProductID = externalProductID
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.servingDescription = servingDescription
        self.gramsPerServing = gramsPerServing
        self.caloriesPerServing = caloriesPerServing
        self.proteinPerServing = proteinPerServing
        self.fatPerServing = fatPerServing
        self.carbsPerServing = carbsPerServing
        self.saturatedFatPerServing = saturatedFatPerServing
        self.fiberPerServing = fiberPerServing
        self.sugarsPerServing = sugarsPerServing
        self.addedSugarsPerServing = addedSugarsPerServing
        self.sodiumPerServing = sodiumPerServing
        self.cholesterolPerServing = cholesterolPerServing
        self.secondaryNutrientBackfillStateRaw = secondaryNutrientBackfillState?.rawValue
        self.searchableText = FoodItem.makeSearchableText(name: name, brand: brand, barcode: barcode, aliases: aliases)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var sourceKind: FoodSource {
        FoodSource(rawValue: source) ?? .custom
    }

    var isMissingAllSecondaryNutrients: Bool {
        saturatedFatPerServing == nil
            && fiberPerServing == nil
            && sugarsPerServing == nil
            && addedSugarsPerServing == nil
            && sodiumPerServing == nil
            && cholesterolPerServing == nil
    }

    var secondaryNutrientBackfillState: SecondaryNutrientBackfillState? {
        get {
            guard let secondaryNutrientBackfillStateRaw else { return nil }
            return SecondaryNutrientBackfillState(rawValue: secondaryNutrientBackfillStateRaw)
        }
        set {
            secondaryNutrientBackfillStateRaw = newValue?.rawValue
        }
    }

    var expectedSearchableText: String {
        FoodItem.makeSearchableText(name: name, brand: brand, barcode: barcode, aliases: [])
    }

    var needsSearchableTextRepair: Bool {
        searchableText != expectedSearchableText
    }

    func normalizeForPersistence() {
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        servingDescription = servingDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        brand = TextNormalization.trimmedNonEmpty(brand)
        barcode = TextNormalization.trimmedNonEmpty(barcode)
        externalProductID = TextNormalization.trimmedNonEmpty(externalProductID)
        sourceName = TextNormalization.trimmedNonEmpty(sourceName)
        sourceURL = TextNormalization.trimmedNonEmpty(sourceURL)

        updateSearchableText()
    }

    func updateSearchableText(with aliases: [String] = [], updateTimestamp: Bool = true) {
        searchableText = FoodItem.makeSearchableText(name: name, brand: brand, barcode: barcode, aliases: aliases)
        if updateTimestamp {
            updatedAt = .now
        }
    }

    private static func makeSearchableText(name: String, brand: String?, barcode: String?, aliases: [String]) -> String {
        var seen = Set<String>()
        return ([name, brand, barcode] + aliases)
            .compactMap(normalizedSearchValue)
            .filter { seen.insert($0).inserted }
            .joined(separator: " ")
    }

    private static func normalizedSearchValue(_ value: String?) -> String? {
        guard let value = TextNormalization.trimmedNonEmpty(value) else { return nil }
        return FoodItemSearchQuery.normalize(value)
    }
}

struct FoodItemSearchQuery: Hashable {
    let normalizedText: String
    let tokens: Set<String>

    init(_ query: String) {
        let normalizedText = Self.normalize(query.trimmingCharacters(in: .whitespacesAndNewlines))
        self.normalizedText = normalizedText
        tokens = Set(Self.tokenize(normalizedText))
    }

    var searchTerm: String {
        tokens.sorted().first(where: { $0.allSatisfy(\.isNumber) })
            ?? tokens.sorted {
                $0.count == $1.count ? $0 < $1 : $0.count > $1.count
            }.first
            ?? normalizedText
    }

    static func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
    }

    static func tokenize(_ value: String) -> [String] {
        normalize(value)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    var isEmpty: Bool {
        normalizedText.isEmpty
    }
}

enum FoodItemLocalSearch {
    private static let secondaryFoodModifiers: Set<String> = [
        "baby", "bread", "bubble", "cake", "chip", "chips", "chocolate", "cinnamon", "cookie", "condensed",
        "chestnut", "chesnut", "dressing", "dry", "evaporated", "franks", "fruit", "ginger", "malted", "parfait",
        "patty",
        "pancake", "rice", "salad", "sauce", "stuffing", "substitute", "syrup", "tartare", "teriyaki", "tomato",
        "tube"
    ]

    private struct SearchMatch {
        let food: FoodItem
        let rank: Int
    }

    static func rankedFoods(_ foods: [FoodItem], matching query: String) -> [FoodItem] {
        let searchQuery = FoodItemSearchQuery(query)
        guard searchQuery.isEmpty == false else { return foods }

        let searchMatches: [SearchMatch] = foods.compactMap { food in
            guard let rank = rank(for: food, matching: searchQuery) else {
                return nil
            }
            return SearchMatch(food: food, rank: rank)
        }

        let rankedMatches = searchMatches.sorted { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            if lhs.food.name.count != rhs.food.name.count {
                return lhs.food.name.count < rhs.food.name.count
            }
            return lhs.food.name.localizedCaseInsensitiveCompare(rhs.food.name) == .orderedAscending
        }

        return rankedMatches.map { $0.food }
    }

    static func rank(for food: FoodItem, matching query: FoodItemSearchQuery) -> Int? {
        let name = FoodItemSearchQuery.normalize(food.name.trimmingCharacters(in: .whitespacesAndNewlines))
        let brand = FoodItemSearchQuery.normalize(food.brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")

        if name == query.normalizedText || (brand.isEmpty == false && brand == query.normalizedText) {
            return 0
        }

        let nameTokens = Set(FoodItemSearchQuery.tokenize(name))
        if query.tokens.isSubset(of: nameTokens) {
            if hasSecondaryModifier(in: nameTokens, query: query.tokens) {
                return 300 + nameTokens.count
            }
            if hasWordPrefix(name, query: query.normalizedText) {
                return 1 + nameTokens.count
            }
            return 20 + nameTokens.count
        }

        if hasWordPrefix(name, query: query.normalizedText) {
            return 50 + nameTokens.count
        }

        let hasTokenPrefixMatch = query.tokens.allSatisfy { queryToken in
            nameTokens.contains(where: { $0.hasPrefix(queryToken) })
        }
        if hasTokenPrefixMatch {
            return 100 + nameTokens.count
        }

        if name.hasPrefix(query.normalizedText) {
            return 150 + nameTokens.count
        }

        if hasWordPrefix(brand, query: query.normalizedText) {
            return 150
        }

        let searchableTokens = Set(FoodItemSearchQuery.tokenize(food.searchableText))
        if query.tokens.isSubset(of: searchableTokens) {
            return 200
        }

        return nil
    }

    private static func hasSecondaryModifier(in nameTokens: Set<String>, query: Set<String>) -> Bool {
        !secondaryFoodModifiers.isDisjoint(with: nameTokens.subtracting(query))
    }

    private static func hasWordPrefix(_ value: String, query: String) -> Bool {
        guard value.hasPrefix(query) else { return false }
        guard let nextCharacter = value.dropFirst(query.count).first else { return true }
        return !nextCharacter.isLetter && !nextCharacter.isNumber
    }

}
