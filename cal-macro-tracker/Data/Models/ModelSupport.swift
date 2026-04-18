import Foundation

enum FoodSource: String, Codable, CaseIterable {
    case common
    case custom
    case barcodeLookup
    case labelScan
    case searchLookup
}

enum QuantityMode: String, Codable, CaseIterable {
    case servings
    case grams
}

enum SecondaryNutrientBackfillState: String, Codable {
    case current
    case needsRepair
    case notRepairable
}

struct SecondaryNutrientRepairKey: Hashable {
    let source: FoodSource
    let name: String
    let brand: String?
    let servingDescription: String
    let gramsPerServing: Double?
    let caloriesPerServing: Double
    let proteinPerServing: Double
    let fatPerServing: Double
    let carbsPerServing: Double

    init(
        source: FoodSource,
        name: String,
        brand: String?,
        servingDescription: String,
        gramsPerServing: Double?,
        caloriesPerServing: Double,
        proteinPerServing: Double,
        fatPerServing: Double,
        carbsPerServing: Double
    ) {
        self.source = source
        self.name = SecondaryNutrientRepairKey.normalizedText(name)
        self.brand = SecondaryNutrientRepairKey.trimmedText(brand)
        self.servingDescription = SecondaryNutrientRepairKey.normalizedText(servingDescription)
        self.gramsPerServing = gramsPerServing
        self.caloriesPerServing = caloriesPerServing
        self.proteinPerServing = proteinPerServing
        self.fatPerServing = fatPerServing
        self.carbsPerServing = carbsPerServing
    }

    private static func normalizedText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func trimmedText(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized?.isEmpty == false ? normalized : nil
    }
}

enum SecondaryNutrientRepairTarget: Hashable {
    case openFoodFactsBarcode(String)
    case usdaFood(Int)

    static func resolve(
        source: FoodSource,
        externalProductID: String?,
        barcode: String?,
        sourceURL: String?
    ) -> SecondaryNutrientRepairTarget? {
        switch source {
        case .barcodeLookup:
            guard
                let barcode = normalizedBarcode(
                    barcode: barcode,
                    externalProductID: externalProductID,
                    sourceURL: sourceURL
                )
            else { return nil }
            return .openFoodFactsBarcode(barcode)
        case .searchLookup:
            if let usdaFoodID = usdaFoodID(from: externalProductID) {
                return .usdaFood(usdaFoodID)
            }

            guard
                let barcode = normalizedBarcode(
                    barcode: barcode,
                    externalProductID: externalProductID,
                    sourceURL: sourceURL
                )
            else { return nil }
            return .openFoodFactsBarcode(barcode)
        case .common, .custom, .labelScan:
            return nil
        }
    }

    private static func normalizedBarcode(
        barcode: String?,
        externalProductID: String?,
        sourceURL: String?
    ) -> String? {
        OpenFoodFactsIdentity.normalizedBarcode(
            barcode: barcode,
            externalProductID: externalProductID,
            sourceURL: sourceURL
        )
    }

    private static func usdaFoodID(from externalProductID: String?) -> Int? {
        guard let externalProductID = externalProductID?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }

        let normalizedExternalProductID = externalProductID.lowercased()
        let prefix = "usda:"
        guard normalizedExternalProductID.hasPrefix(prefix) else { return nil }
        return Int(normalizedExternalProductID.dropFirst(prefix.count))
    }
}

enum SecondaryNutrientBackfillPolicy {
    struct UpdateResolution {
        let draft: FoodDraft
        let state: SecondaryNutrientBackfillState
    }

    static func inferredState(for food: FoodItem) -> SecondaryNutrientBackfillState {
        state(
            isMissingAllSecondaryNutrients: food.isMissingAllSecondaryNutrients,
            source: food.sourceKind,
            hasRepairTarget: food.secondaryNutrientRepairTarget != nil
        )
    }

    static func inferredState(for entry: LogEntry) -> SecondaryNutrientBackfillState {
        state(
            isMissingAllSecondaryNutrients: entry.isMissingAllSecondaryPerServingNutrients
                && entry.isMissingAllSecondaryConsumedNutrients,
            source: entry.sourceKind,
            hasRepairTarget: entry.secondaryNutrientRepairTarget != nil || entry.foodItemID != nil
        )
    }

    static func resolvedStateForNewRecord(from draft: FoodDraft) -> SecondaryNutrientBackfillState {
        draft.secondaryNutrientBackfillState ?? .current
    }

    static func resolvedUpdatedState(
        initialState: SecondaryNutrientBackfillState,
        initialKey: SecondaryNutrientRepairKey,
        updatedKey: SecondaryNutrientRepairKey,
        hasSecondaryNutrientChanges: Bool
    ) -> SecondaryNutrientBackfillState {
        if hasSecondaryNutrientChanges {
            return .current
        }

        if updatedKey != initialKey, initialState != .current {
            return .notRepairable
        }

        return initialState
    }

    static func resolvedUpdate(
        initialDraft: FoodDraft,
        updatedDraft: FoodDraft,
        initialState: SecondaryNutrientBackfillState
    ) -> UpdateResolution {
        let hasSecondaryNutrientChanges = updatedDraft.hasSecondaryNutrientChanges(comparedTo: initialDraft)
        let updatedState = resolvedUpdatedState(
            initialState: initialState,
            initialKey: initialDraft.secondaryNutrientRepairKey,
            updatedKey: updatedDraft.secondaryNutrientRepairKey,
            hasSecondaryNutrientChanges: hasSecondaryNutrientChanges
        )

        guard
            hasSecondaryNutrientChanges == false,
            updatedDraft.secondaryNutrientRepairKey != initialDraft.secondaryNutrientRepairKey,
            initialState == .current,
            initialDraft.isMissingAllSecondaryNutrients == false
        else {
            return UpdateResolution(draft: updatedDraft, state: updatedState)
        }

        return UpdateResolution(
            draft: updatedDraft,
            state: .notRepairable
        )
    }

    private static func state(
        isMissingAllSecondaryNutrients: Bool,
        source: FoodSource,
        hasRepairTarget: Bool
    ) -> SecondaryNutrientBackfillState {
        guard isMissingAllSecondaryNutrients else { return .current }

        switch source {
        case .common:
            return .needsRepair
        case .barcodeLookup, .searchLookup:
            return hasRepairTarget ? .needsRepair : .current
        case .custom, .labelScan:
            return .current
        }
    }
}

extension FoodDraft {
    var isMissingAllSecondaryNutrients: Bool {
        saturatedFatPerServing == nil
            && fiberPerServing == nil
            && sugarsPerServing == nil
            && addedSugarsPerServing == nil
            && sodiumPerServing == nil
            && cholesterolPerServing == nil
    }

    var shouldOfferManualSecondaryNutrientRefresh: Bool {
        switch source {
        case .barcodeLookup, .searchLookup:
            return isMissingAllSecondaryNutrients && secondaryNutrientBackfillState != .notRepairable
        case .common, .custom, .labelScan:
            return false
        }
    }

    var secondaryNutrientRepairKey: SecondaryNutrientRepairKey {
        SecondaryNutrientRepairKey(
            source: source,
            name: name,
            brand: brandOrNil,
            servingDescription: servingDescription,
            gramsPerServing: gramsPerServing,
            caloriesPerServing: caloriesPerServing,
            proteinPerServing: proteinPerServing,
            fatPerServing: fatPerServing,
            carbsPerServing: carbsPerServing
        )
    }

    var secondaryNutrientRepairTarget: SecondaryNutrientRepairTarget? {
        SecondaryNutrientRepairTarget.resolve(
            source: source,
            externalProductID: externalProductIDOrNil,
            barcode: barcodeOrNil,
            sourceURL: sourceURLOrNil
        )
    }
}

extension FoodItem {
    var secondaryNutrientRepairKey: SecondaryNutrientRepairKey {
        SecondaryNutrientRepairKey(
            source: sourceKind,
            name: name,
            brand: brand,
            servingDescription: servingDescription,
            gramsPerServing: gramsPerServing,
            caloriesPerServing: caloriesPerServing,
            proteinPerServing: proteinPerServing,
            fatPerServing: fatPerServing,
            carbsPerServing: carbsPerServing
        )
    }

    var secondaryNutrientRepairTarget: SecondaryNutrientRepairTarget? {
        SecondaryNutrientRepairTarget.resolve(
            source: sourceKind,
            externalProductID: externalProductID,
            barcode: barcode,
            sourceURL: sourceURL
        )
    }
}

extension LogEntry {
    var secondaryNutrientRepairKey: SecondaryNutrientRepairKey {
        SecondaryNutrientRepairKey(
            source: sourceKind,
            name: foodName,
            brand: brand,
            servingDescription: servingDescription,
            gramsPerServing: gramsPerServing,
            caloriesPerServing: caloriesPerServing,
            proteinPerServing: proteinPerServing,
            fatPerServing: fatPerServing,
            carbsPerServing: carbsPerServing
        )
    }

    var secondaryNutrientRepairTarget: SecondaryNutrientRepairTarget? {
        SecondaryNutrientRepairTarget.resolve(
            source: sourceKind,
            externalProductID: externalProductIDOrNil,
            barcode: barcodeOrNil,
            sourceURL: sourceURLOrNil
        )
    }
}

enum NumericText {
    enum State: Equatable {
        case empty
        case valid(Double)
        case invalid

        var value: Double? {
            switch self {
            case .empty, .invalid:
                nil
            case let .valid(value):
                value
            }
        }

        var isInvalid: Bool {
            if case .invalid = self {
                return true
            }

            return false
        }
    }

    static func editingDisplay(for value: Double, emptyWhenZero: Bool = false) -> String {
        if emptyWhenZero, abs(value) < 0.000_1 {
            return ""
        }

        return value.formatted(numberStyle)
    }

    static func editingDisplay(for value: Double?) -> String {
        guard let value else { return "" }
        return editingDisplay(for: value)
    }

    static func state(for text: String) -> State {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        do {
            return .valid(try numberStyle.parseStrategy.parse(trimmed))
        } catch {
            if let number = Double(trimmed) {
                return .valid(number)
            }

            return .invalid
        }
    }

    static func parse(_ text: String) -> Double? {
        state(for: text).value
    }

    private static let numberStyle = FloatingPointFormatStyle<Double>.number
        .grouping(.never)
        .precision(.fractionLength(0...16))
        .locale(.current)
}

extension Double {
    var roundedForDisplay: String {
        if abs(self.rounded() - self) < 0.01 {
            return String(Int(self.rounded()))
        }

        return String(format: "%.1f", self)
    }
}

struct DayInterval: Hashable {
    let start: Date
    let end: Date
}

struct CalendarDay: Hashable, Sendable {
    let calendarIdentifier: Calendar.Identifier
    let era: Int?
    let year: Int
    let month: Int
    let day: Int

    init(date: Date, calendar: Calendar = .current) {
        calendarIdentifier = calendar.identifier
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        era = components.era
        year = components.year ?? 0
        month = components.month ?? 1
        day = components.day ?? 1
    }

    var startDate: Date {
        let calendar = resolvedCalendar
        guard let date = calendar.date(from: dateComponents) else {
            return Date()
        }

        return calendar.startOfDay(for: date)
    }

    var dayInterval: DayInterval {
        let calendar = resolvedCalendar
        let start = startDate
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return DayInterval(start: start, end: end)
    }

    var weekDays: [CalendarDay] {
        let calendar = resolvedCalendar
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: startDate) else {
            return [self]
        }

        let weekStart = CalendarDay(date: interval.start, calendar: calendar)
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart.startDate).map {
                CalendarDay(date: $0, calendar: calendar)
            }
        }
    }

    var dayTitle: String {
        if isToday {
            return "Today"
        }

        return startDate.formatted(date: .abbreviated, time: .omitted)
    }

    var weekdayNarrowTitle: String {
        startDate.formatted(.dateTime.weekday(.narrow))
    }

    var weekdayAccessibilityTitle: String {
        startDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var historyNavigationTitle: String {
        let dateTitle = startDate.formatted(.dateTime.month(.abbreviated).day().year())

        if isToday {
            return "Today, \(dateTitle)"
        }

        return "\(startDate.formatted(.dateTime.weekday(.wide))), \(dateTitle)"
    }

    var isToday: Bool {
        self == CalendarDay(date: Date(), calendar: resolvedCalendar)
    }

    private var dateComponents: DateComponents {
        var components = DateComponents()
        components.era = era
        components.year = year
        components.month = month
        components.day = day
        return components
    }

    private var resolvedCalendar: Calendar {
        var calendar = Calendar(identifier: calendarIdentifier)
        calendar.locale = .current
        calendar.timeZone = .current
        return calendar
    }
}

extension Date {
    var calendarDay: CalendarDay {
        CalendarDay(date: self)
    }

    var timeTitle: String {
        formatted(date: .omitted, time: .shortened)
    }
}
