import Foundation

enum FoodDraftValidationError: LocalizedError {
    case missingName
    case missingServingDescription
    case invalidGramsPerServing
    case invalidValue(String)
    case negativeCalories
    case negativeProtein
    case negativeFat
    case negativeCarbs
    case negativeSaturatedFat
    case negativeFiber
    case negativeSugars
    case negativeAddedSugars
    case negativeSodium
    case negativeCholesterol
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
        case let .invalidValue(name):
            "\(name) must be a finite number."
        case .negativeCalories:
            "Calories cannot be negative."
        case .negativeProtein:
            "Protein cannot be negative."
        case .negativeFat:
            "Fat cannot be negative."
        case .negativeCarbs:
            "Carbs cannot be negative."
        case .negativeSaturatedFat:
            "Saturated fat cannot be negative."
        case .negativeFiber:
            "Fiber cannot be negative."
        case .negativeSugars:
            "Sugars cannot be negative."
        case .negativeAddedSugars:
            "Added sugars cannot be negative."
        case .negativeSodium:
            "Sodium cannot be negative."
        case .negativeCholesterol:
            "Cholesterol cannot be negative."
        case .invalidQuantity:
            "Enter an amount greater than zero."
        case .gramsPerServingRequiredForGramLogging:
            "Add grams per serving to log by grams."
        }
    }
}

enum ReusableFoodPersistenceMode: Equatable {
    case none
    case userRequested
    case autoCreateFromCommonEdits
    case autoUpdateExistingExternalFood

    var shouldPersistReusableFood: Bool {
        self != .none
    }
}

extension FoodDraft {
    var brandOrNil: String? {
        Self.trimmedText(from: brand)
    }

    var barcodeOrNil: String? {
        Self.trimmedText(from: barcode)
    }

    var externalProductIDOrNil: String? {
        Self.trimmedText(from: externalProductID)
    }

    var sourceNameOrNil: String? {
        Self.trimmedText(from: sourceName)
    }

    var sourceURLOrNil: String? {
        Self.trimmedText(from: sourceURL)
    }

    var canLogByGrams: Bool {
        guard let gramsPerServing else { return false }
        return gramsPerServing.isFinite && gramsPerServing > 0
    }

    func missingLabelScanRequiredNutrients(
        from nutrients: [RequiredNutritionReviewNutrient],
        confirmedZeroNutrients: Set<RequiredNutritionReviewNutrient>
    ) -> [RequiredNutritionReviewNutrient] {
        nutrients.filter { nutrient in
            isRequiredNutrientPositive(nutrient) == false && confirmedZeroNutrients.contains(nutrient) == false
        }
    }

    func isRequiredNutrientPositive(_ nutrient: RequiredNutritionReviewNutrient) -> Bool {
        requiredNutrientValue(for: nutrient) > 0
    }

    var canSaveReusableFood: Bool {
        validationErrorForSaving() == nil
    }

    func hasMeaningfulChanges(comparedTo other: FoodDraft) -> Bool {
        normalized().hasMeaningfulChanges(comparedToNormalized: other.normalized())
    }

    func hasSecondaryNutrientChanges(comparedTo other: FoodDraft) -> Bool {
        normalized().hasSecondaryNutrientChanges(comparedToNormalized: other.normalized())
    }

    static func reusableFoodPersistenceMode(
        initialDraft: FoodDraft,
        currentDraft: FoodDraft
    ) -> ReusableFoodPersistenceMode {
        let normalizedInitialDraft = initialDraft.normalized()
        let normalizedCurrentDraft = currentDraft.normalized()

        if normalizedCurrentDraft.saveAsCustomFood {
            return .userRequested
        }

        guard normalizedCurrentDraft.hasMeaningfulChanges(comparedToNormalized: normalizedInitialDraft) else {
            return .none
        }

        switch normalizedInitialDraft.source {
        case .common:
            return .autoCreateFromCommonEdits
        case .custom:
            return .none
        case .barcodeLookup, .labelScan, .searchLookup:
            return normalizedInitialDraft.foodItemID == nil ? .none : .autoUpdateExistingExternalFood
        }
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

        if let gramsPerServing = draft.gramsPerServing, gramsPerServing.isFinite == false || gramsPerServing <= 0 {
            return .invalidGramsPerServing
        }

        for rule in draft.nutritionValidationRules {
            if let error = draft.nutritionValidationError(
                name: rule.name,
                value: rule.value,
                negativeError: rule.negativeError
            ) {
                return error
            }
        }

        return nil
    }

    func validationErrorForLogging(
        quantityMode: QuantityMode,
        quantityAmount: Double
    ) -> FoodDraftValidationError? {
        if let validationError = validationErrorForSaving() {
            return validationError
        }

        guard quantityAmount.isFinite, quantityAmount > 0 else {
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
        draft.barcode = barcodeOrNil ?? ""
        draft.externalProductID = externalProductIDOrNil ?? ""
        draft.sourceName = sourceNameOrNil ?? ""
        draft.sourceURL = sourceURLOrNil ?? ""
        draft.servingDescription = servingDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return draft
    }

    private static func trimmedText(from value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func hasMeaningfulChanges(comparedToNormalized other: FoodDraft) -> Bool {
        name != other.name
            || brand != other.brand
            || source != other.source
            || barcode != other.barcode
            || externalProductID != other.externalProductID
            || sourceName != other.sourceName
            || sourceURL != other.sourceURL
            || servingDescription != other.servingDescription
            || gramsPerServing != other.gramsPerServing
            || caloriesPerServing != other.caloriesPerServing
            || proteinPerServing != other.proteinPerServing
            || fatPerServing != other.fatPerServing
            || carbsPerServing != other.carbsPerServing
            || hasSecondaryNutrientChanges(comparedToNormalized: other)
    }

    private func hasSecondaryNutrientChanges(comparedToNormalized other: FoodDraft) -> Bool {
        saturatedFatPerServing != other.saturatedFatPerServing
            || fiberPerServing != other.fiberPerServing
            || sugarsPerServing != other.sugarsPerServing
            || addedSugarsPerServing != other.addedSugarsPerServing
            || sodiumPerServing != other.sodiumPerServing
            || cholesterolPerServing != other.cholesterolPerServing
    }

    private func requiredNutrientValue(for nutrient: RequiredNutritionReviewNutrient) -> Double {
        switch nutrient {
        case .calories:
            caloriesPerServing
        case .protein:
            proteinPerServing
        case .fat:
            fatPerServing
        case .carbs:
            carbsPerServing
        }
    }

    private var nutritionValidationRules: [(name: String, value: Double?, negativeError: FoodDraftValidationError)] {
        [
            ("Calories", caloriesPerServing, .negativeCalories),
            ("Protein", proteinPerServing, .negativeProtein),
            ("Fat", fatPerServing, .negativeFat),
            ("Carbs", carbsPerServing, .negativeCarbs),
            ("Saturated fat", saturatedFatPerServing, .negativeSaturatedFat),
            ("Fiber", fiberPerServing, .negativeFiber),
            ("Sugars", sugarsPerServing, .negativeSugars),
            ("Added sugars", addedSugarsPerServing, .negativeAddedSugars),
            ("Sodium", sodiumPerServing, .negativeSodium),
            ("Cholesterol", cholesterolPerServing, .negativeCholesterol)
        ]
    }

    private func nutritionValidationError(
        name: String,
        value: Double?,
        negativeError: FoodDraftValidationError
    ) -> FoodDraftValidationError? {
        guard let value else { return nil }
        guard value.isFinite else { return .invalidValue(name) }
        return value < 0 ? negativeError : nil
    }
}
