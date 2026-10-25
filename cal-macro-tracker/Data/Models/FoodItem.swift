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
            .joined(separator: FoodItemLocalSearch.searchableValueSeparator)
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

    nonisolated static func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
    }

    nonisolated static func tokenize(_ value: String) -> [String] {
        normalize(value)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    var isEmpty: Bool {
        normalizedText.isEmpty
    }
}

enum FoodItemLocalSearch {
    static let searchableValueSeparator = "\n"

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
            let nameOrder = lhs.food.name.compare(
                rhs.food.name,
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return lhs.food.id.uuidString < rhs.food.id.uuidString
        }

        return rankedMatches.map { $0.food }
    }

    static func rank(for food: FoodItem, matching query: FoodItemSearchQuery) -> Int? {
        let queryWords = comparableWords(query.normalizedText)
        guard queryWords.isEmpty == false else { return nil }

        let nameSegments = food.name.split(separator: ",").map(String.init)
        let firstNameSegment = nameSegments.first ?? food.name
        let firstNameWords = comparableWords(firstNameSegment)
        let prefixValues = [food.name, food.brand, food.barcode]
            .compactMap { TextNormalization.trimmedNonEmpty($0).map(FoodItemSearchQuery.normalize) }
            .reduce(into: [String]()) { values, value in
                if values.contains(value) == false {
                    values.append(value)
                }
            }
        let searchableComponents = food.searchableText.components(separatedBy: Self.searchableValueSeparator)
        let aliasWords: [[String]]
        if searchableComponents.count > 1 {
            aliasWords = Array(searchableComponents.dropFirst(prefixValues.count)).map(comparableWords)
        } else {
            let prefixWordCount = prefixValues.reduce(into: 0) { count, value in
                count += comparableWords(value).count
            }
            aliasWords = [Array(comparableWords(food.searchableText).dropFirst(prefixWordCount))]
        }
        let brandWords = food.brand.map(comparableWords) ?? []
        let tier: Int
        if phraseEquals(firstNameWords, queryWords)
            || phraseEquals(brandWords, queryWords)
            || aliasWords.contains(where: { phraseEquals($0, queryWords) })
        {
            tier = 0
        } else if headNounMatches(firstNameWords, queryWords) {
            tier = 1
        } else if containsWords(firstNameWords, queryWords, allowingPrefix: true) {
            tier = 2
        } else {
            let laterNameSegments = nameSegments.dropFirst().map { comparableWords($0) }
            guard
                laterNameSegments.contains(where: { containsWords($0, queryWords, allowingPrefix: true) })
                    || aliasWords.contains(where: { containsWords($0, queryWords, allowingPrefix: true) })
            else { return nil }
            tier = 3
        }

        let commaSegmentPenalty = min(nameSegments.count, 99) * 100_000
        let nameLengthPenalty = min(food.name.count, 99_999)
        return tier * 10_000_000 + commaSegmentPenalty + nameLengthPenalty
    }

    nonisolated private static func comparableWords(_ value: String) -> [String] {
        FoodItemSearchQuery.tokenize(value).map(singularize)
    }

    nonisolated private static func singularize(_ word: String) -> String {
        if word.count > 4, word.hasSuffix("ies") {
            return String(word.dropLast(3)) + "y"
        }
        if word.count > 4, ["ches", "shes", "xes", "zes"].contains(where: word.hasSuffix) {
            return String(word.dropLast(2))
        }
        if word.count > 3, word.hasSuffix("s"), word.hasSuffix("ss") == false {
            return String(word.dropLast())
        }
        return word
    }

    nonisolated private static func phraseEquals(_ lhs: [String], _ rhs: [String]) -> Bool {
        lhs == rhs
    }

    nonisolated private static func headNounMatches(_ words: [String], _ query: [String]) -> Bool {
        query.count <= words.count && Array(words.suffix(query.count)) == query
    }

    nonisolated private static func containsWords(_ words: [String], _ query: [String], allowingPrefix: Bool) -> Bool {
        guard query.count <= words.count else { return false }
        return (0...(words.count - query.count)).contains { start in
            zip(words[start..<(start + query.count)], query).allSatisfy { word, queryWord in
                allowingPrefix ? word.hasPrefix(queryWord) : word == queryWord
            }
        }
    }
}
