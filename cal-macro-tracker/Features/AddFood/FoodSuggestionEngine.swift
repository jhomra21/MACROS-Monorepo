import Foundation

struct FoodSuggestion: Identifiable {
    let id: String
    let foodName: String
    let sourceEntry: LogEntry
}

enum FoodSuggestionEngine {
    private struct Candidate {
        let identity: FoodSuggestionIdentity
        let foodName: String
        var score: Int
        var totalCount: Int
        var latestEntry: LogEntry
        var bestMatchingEntry: LogEntry
        var bestMatchingScore: Int
    }

    static func suggestions(
        from entries: [LogEntry],
        now: Date = .now,
        calendar: Calendar = .current,
        limit: Int = 5
    ) -> [FoodSuggestion] {
        let today = CalendarDay(date: now, calendar: calendar)
        let distinctDays = Set(entries.map { CalendarDay(date: $0.dateLogged, calendar: calendar) })
        guard distinctDays.count >= 2 else { return [] }

        let todayIdentities = Set(
            entries.filter { CalendarDay(date: $0.dateLogged, calendar: calendar) == today }.map(FoodSuggestionIdentity.init))
        let repeatWithinDayIdentities = repeatedWithinDayIdentities(in: entries, calendar: calendar)
        let nowWindow = FoodSuggestionTimeWindow(date: now, calendar: calendar)
        let weekday = calendar.component(.weekday, from: now)

        var candidates = [FoodSuggestionIdentity: Candidate]()

        for entry in entries {
            let identity = FoodSuggestionIdentity(entry)
            guard todayIdentities.contains(identity) == false || repeatWithinDayIdentities.contains(identity) else { continue }

            let daysAgo = calendar.dateComponents([.day], from: entry.dateLogged, to: now).day ?? 0
            guard daysAgo >= 0, daysAgo <= 14 else { continue }

            let entryWindow = FoodSuggestionTimeWindow(date: entry.dateLogged, calendar: calendar)
            let entryWeekday = calendar.component(.weekday, from: entry.dateLogged)
            let matches = FoodSuggestionScoreMatches(
                isRecent: daysAgo <= 3,
                isTimeOfDay: daysAgo <= 7 && entryWindow == nowWindow,
                isWeekday: daysAgo <= 14 && entryWeekday == weekday
            )
            let entryScore = score(for: matches)

            var candidate =
                candidates[identity]
                ?? Candidate(
                    identity: identity,
                    foodName: entry.foodName,
                    score: 0,
                    totalCount: 0,
                    latestEntry: entry,
                    bestMatchingEntry: entry,
                    bestMatchingScore: 0
                )

            candidate.score += entryScore
            candidate.totalCount += 1

            if entry.dateLogged > candidate.latestEntry.dateLogged {
                candidate.latestEntry = entry
            }
            if entryScore > candidate.bestMatchingScore {
                candidate.bestMatchingEntry = entry
                candidate.bestMatchingScore = entryScore
            }

            candidates[identity] = candidate
        }

        return candidates.values
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                if lhs.latestEntry.dateLogged != rhs.latestEntry.dateLogged {
                    return lhs.latestEntry.dateLogged > rhs.latestEntry.dateLogged
                }
                if lhs.totalCount != rhs.totalCount { return lhs.totalCount > rhs.totalCount }
                return lhs.foodName.localizedCaseInsensitiveCompare(rhs.foodName) == .orderedAscending
            }
            .prefix(limit)
            .map {
                FoodSuggestion(
                    id: $0.identity.rawValue,
                    foodName: $0.foodName,
                    sourceEntry: $0.bestMatchingEntry
                )
            }
    }

    private static func repeatedWithinDayIdentities(in entries: [LogEntry], calendar: Calendar) -> Set<FoodSuggestionIdentity> {
        let countsByDay = Dictionary(grouping: entries) { entry in
            FoodSuggestionDayIdentity(day: CalendarDay(date: entry.dateLogged, calendar: calendar), identity: FoodSuggestionIdentity(entry))
        }

        let repeatedDaysByIdentity = countsByDay.reduce(into: [FoodSuggestionIdentity: Int]()) { result, pair in
            guard pair.value.count >= 2 else { return }
            result[pair.key.identity, default: 0] += 1
        }

        return Set(
            repeatedDaysByIdentity.compactMap { identity, count in
                count >= 2 ? identity : nil
            })
    }

    private static func score(for matches: FoodSuggestionScoreMatches) -> Int {
        (matches.isRecent ? 30 : 0) + (matches.isTimeOfDay ? 24 : 0) + (matches.isWeekday ? 18 : 0) + 4
    }

}

private struct FoodSuggestionScoreMatches {
    let isRecent: Bool
    let isTimeOfDay: Bool
    let isWeekday: Bool
}

private struct FoodSuggestionIdentity: Hashable {
    private enum Kind: Hashable {
        case foodItem(UUID)
        case barcode(String)
        case external(source: String, externalProductID: String)
        case normalizedText(String)
    }

    private let kind: Kind

    var rawValue: String {
        switch kind {
        case .foodItem(let id):
            return "foodItem:\(id.uuidString)"
        case .barcode(let barcode):
            return "barcode:\(barcode)"
        case .external(let source, let externalProductID):
            return "external:\(source):\(externalProductID)"
        case .normalizedText(let value):
            return value
        }
    }

    init(_ entry: LogEntry) {
        if let foodItemID = entry.foodItemID {
            kind = .foodItem(foodItemID)
        } else if let barcode = OpenFoodFactsIdentity.normalizedBarcode(
            barcode: entry.barcodeOrNil,
            externalProductID: entry.externalProductIDOrNil,
            sourceURL: entry.sourceURLOrNil
        ) {
            kind = .barcode(barcode)
        } else if let externalProductID = entry.externalProductIDOrNil {
            kind = .external(source: entry.source, externalProductID: externalProductID.lowercased())
        } else {
            kind = .normalizedText(
                [
                    entry.brand ?? "",
                    entry.foodName,
                    entry.servingDescription
                ]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .joined(separator: "|")
            )
        }
    }
}

private struct FoodSuggestionDayIdentity: Equatable, Hashable {
    let day: CalendarDay
    let identity: FoodSuggestionIdentity

    static func == (lhs: FoodSuggestionDayIdentity, rhs: FoodSuggestionDayIdentity) -> Bool {
        lhs.day == rhs.day && lhs.identity == rhs.identity
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(day)
        hasher.combine(identity)
    }
}

private enum FoodSuggestionTimeWindow: Hashable {
    case morning
    case midday
    case evening
    case late

    init(date: Date, calendar: Calendar) {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<11:
            self = .morning
        case 11..<15:
            self = .midday
        case 15..<21:
            self = .evening
        default:
            self = .late
        }
    }
}
