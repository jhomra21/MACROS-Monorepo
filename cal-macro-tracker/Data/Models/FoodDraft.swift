import Foundation

enum FoodDraftValidationError: LocalizedError {
    case missingName
    case missingServingDescription
    case invalidGramsPerServing
    case negativeCalories
    case negativeProtein
    case negativeFat
    case negativeCarbs
    case invalidQuantity
    case gramsPerServingRequiredForGramLogging

    var errorDescription: String? {
        switch self {
        case .missingName:
            "Enter a food name."
        case .missingServingDescription:
            "Enter a serving description."
        case .invalidGramsPerServing:
            "Grams per serving must be greater than zero when provided."
        case .negativeCalories:
            "Calories cannot be negative."
        case .negativeProtein:
            "Protein cannot be negative."
        case .negativeFat:
            "Fat cannot be negative."
        case .negativeCarbs:
            "Carbs cannot be negative."
        case .invalidQuantity:
            "Enter an amount greater than zero."
        case .gramsPerServingRequiredForGramLogging:
            "Add grams per serving to log by grams."
        }
    }
}

struct FoodDraft: Identifiable, Hashable {
    var id: UUID = UUID()
    var foodItemID: UUID?
    var name: String = ""
    var brand: String = ""
    var source: FoodSource = .custom
    var servingDescription: String = "1 serving"
    var gramsPerServing: Double?
    var caloriesPerServing: Double = 0
    var proteinPerServing: Double = 0
    var fatPerServing: Double = 0
    var carbsPerServing: Double = 0
    var saveAsCustomFood: Bool = true

    init() {}

    init(foodItem: FoodItem, saveAsCustomFood: Bool = false) {
        self.id = UUID()
        self.foodItemID = foodItem.id
        self.name = foodItem.name
        self.brand = foodItem.brand ?? ""
        self.source = foodItem.sourceKind
        self.servingDescription = foodItem.servingDescription
        self.gramsPerServing = foodItem.gramsPerServing
        self.caloriesPerServing = foodItem.caloriesPerServing
        self.proteinPerServing = foodItem.proteinPerServing
        self.fatPerServing = foodItem.fatPerServing
        self.carbsPerServing = foodItem.carbsPerServing
        self.saveAsCustomFood = saveAsCustomFood
    }

    var brandOrNil: String? {
        brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : brand.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canLogByGrams: Bool {
        guard let gramsPerServing else { return false }
        return gramsPerServing > 0
    }

    var hasRequiredFields: Bool {
        let normalizedDraft = normalized()
        return !normalizedDraft.name.isEmpty && !normalizedDraft.servingDescription.isEmpty
    }

    var canSaveReusableFood: Bool {
        validationErrorForSaving() == nil
    }

    func canLog(quantityMode: QuantityMode, quantityAmount: Double) -> Bool {
        validationErrorForLogging(quantityMode: quantityMode, quantityAmount: quantityAmount) == nil
    }

    func validationErrorForSaving() -> FoodDraftValidationError? {
        let draft = normalized()

        if draft.name.isEmpty {
            return .missingName
        }

        if draft.servingDescription.isEmpty {
            return .missingServingDescription
        }

        if let gramsPerServing = draft.gramsPerServing, gramsPerServing <= 0 {
            return .invalidGramsPerServing
        }

        if draft.caloriesPerServing < 0 {
            return .negativeCalories
        }

        if draft.proteinPerServing < 0 {
            return .negativeProtein
        }

        if draft.fatPerServing < 0 {
            return .negativeFat
        }

        if draft.carbsPerServing < 0 {
            return .negativeCarbs
        }

        return nil
    }

    func validationErrorForLogging(quantityMode: QuantityMode, quantityAmount: Double) -> FoodDraftValidationError? {
        if let validationError = validationErrorForSaving() {
            return validationError
        }

        guard quantityAmount > 0 else {
            return .invalidQuantity
        }

        if quantityMode == .grams, canLogByGrams == false {
            return .gramsPerServingRequiredForGramLogging
        }

        return nil
    }

    func normalized() -> FoodDraft {
        var draft = self
        draft.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.brand = brandOrNil ?? ""
        draft.servingDescription = servingDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return draft
    }

    func makeCustomFoodItem() -> FoodItem {
        let draft = normalized()

        return FoodItem(
            name: draft.name,
            brand: draft.brandOrNil,
            source: .custom,
            servingDescription: draft.servingDescription,
            gramsPerServing: draft.gramsPerServing,
            caloriesPerServing: draft.caloriesPerServing,
            proteinPerServing: draft.proteinPerServing,
            fatPerServing: draft.fatPerServing,
            carbsPerServing: draft.carbsPerServing
        )
    }
}
