import Foundation

enum FoodDraftValidationError: LocalizedError {
    case missingName
    case missingServingDescription
    case invalidGramsPerServing
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
        return gramsPerServing > 0
    }

    func missingLabelScanRequiredNutrients(
        from nutrients: [RequiredNutritionReviewNutrient],
        confirmedZeroNutrients: Set<RequiredNutritionReviewNutrient>
    ) -> [RequiredNutritionReviewNutrient] {
        nutrients.filter { nutrient in
            requiredNutrientValue(for: nutrient) <= 0 && confirmedZeroNutrients.contains(nutrient) == false
        }
    }

    var canSaveReusableFood: Bool {
        validationErrorForSaving() == nil
    }

    func hasMeaningfulChanges(comparedTo other: FoodDraft) -> Bool {
        let normalizedDraft = normalized()
        let normalizedOther = other.normalized()

        return normalizedDraft.name != normalizedOther.name
            || normalizedDraft.brand != normalizedOther.brand
            || normalizedDraft.source != normalizedOther.source
            || normalizedDraft.barcode != normalizedOther.barcode
            || normalizedDraft.externalProductID != normalizedOther.externalProductID
            || normalizedDraft.sourceName != normalizedOther.sourceName
            || normalizedDraft.sourceURL != normalizedOther.sourceURL
            || normalizedDraft.servingDescription != normalizedOther.servingDescription
            || normalizedDraft.gramsPerServing != normalizedOther.gramsPerServing
            || normalizedDraft.caloriesPerServing != normalizedOther.caloriesPerServing
            || normalizedDraft.proteinPerServing != normalizedOther.proteinPerServing
            || normalizedDraft.fatPerServing != normalizedOther.fatPerServing
            || normalizedDraft.carbsPerServing != normalizedOther.carbsPerServing
            || normalizedDraft.hasSecondaryNutrientChanges(comparedTo: normalizedOther)
    }

    func hasSecondaryNutrientChanges(comparedTo other: FoodDraft) -> Bool {
        let normalizedDraft = normalized()
        let normalizedOther = other.normalized()

        return normalizedDraft.saturatedFatPerServing != normalizedOther.saturatedFatPerServing
            || normalizedDraft.fiberPerServing != normalizedOther.fiberPerServing
            || normalizedDraft.sugarsPerServing != normalizedOther.sugarsPerServing
            || normalizedDraft.addedSugarsPerServing != normalizedOther.addedSugarsPerServing
            || normalizedDraft.sodiumPerServing != normalizedOther.sodiumPerServing
            || normalizedDraft.cholesterolPerServing != normalizedOther.cholesterolPerServing
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

        guard normalizedCurrentDraft.hasMeaningfulChanges(comparedTo: normalizedInitialDraft) else {
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

        if let saturatedFatPerServing = draft.saturatedFatPerServing, saturatedFatPerServing < 0 {
            return .negativeSaturatedFat
        }

        if let fiberPerServing = draft.fiberPerServing, fiberPerServing < 0 {
            return .negativeFiber
        }

        if let sugarsPerServing = draft.sugarsPerServing, sugarsPerServing < 0 {
            return .negativeSugars
        }

        if let addedSugarsPerServing = draft.addedSugarsPerServing, addedSugarsPerServing < 0 {
            return .negativeAddedSugars
        }

        if let sodiumPerServing = draft.sodiumPerServing, sodiumPerServing < 0 {
            return .negativeSodium
        }

        if let cholesterolPerServing = draft.cholesterolPerServing, cholesterolPerServing < 0 {
            return .negativeCholesterol
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
}
