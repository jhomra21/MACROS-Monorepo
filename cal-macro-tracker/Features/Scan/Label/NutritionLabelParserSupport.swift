import Foundation

extension NutritionLabelParser {
    static let capturedNumberPattern = "((?:\\d{1,3}(?:,\\d{3})+|\\d+)(?:\\.\\d+)?)(?!,\\d)"

    enum NutrientAmountUnit: String {
        case grams = "g"
        case milligrams = "mg"
    }

    enum PercentDailyValueNutrient {
        case sodium
        case cholesterol

        var labelPattern: String {
            switch self {
            case .sodium:
                "sodium"
            case .cholesterol:
                "cholesterol"
            }
        }

        var dailyValueMilligrams: Double {
            switch self {
            case .sodium:
                2_300
            case .cholesterol:
                300
            }
        }
    }

    struct DetectedNutrients {
        let calories: Double?
        let protein: Double?
        let fat: Double?
        let carbs: Double?
        let saturatedFat: Double?
        let fiber: Double?
        let sugars: Double?
        let addedSugars: Double?
        let sodium: Double?
        let cholesterol: Double?

        var missingRequiredNutrients: [RequiredNutritionReviewNutrient] {
            [
                calories == nil ? .calories : nil,
                protein == nil ? .protein : nil,
                fat == nil ? .fat : nil,
                carbs == nil ? .carbs : nil
            ]
            .compactMap { $0 }
        }

        var perServingNutritionValues: PerServingNutritionValues {
            PerServingNutritionValues(
                calories: calories ?? 0,
                protein: protein ?? 0,
                fat: fat ?? 0,
                carbs: carbs ?? 0,
                saturatedFat: saturatedFat,
                fiber: fiber,
                sugars: sugars,
                addedSugars: addedSugars,
                sodium: sodium,
                cholesterol: cholesterol
            )
        }
    }

    struct ParsedLabelText {
        let lines: [String]
        let nutritionBlockStartIndex: Int
        let nutritionLines: [String]

        init(recognizedText: NutritionLabelRecognizedText) {
            self.lines = recognizedText.lines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
            self.nutritionBlockStartIndex =
                lines.firstIndex { line in
                    isNutritionBlockLine(line)
                } ?? lines.count
            if nutritionBlockStartIndex < lines.count {
                self.nutritionLines = Array(lines[nutritionBlockStartIndex...])
            } else {
                self.nutritionLines = []
            }
        }
    }

    static func firstMatch(in text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
            let valueRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        return parsedNumber(from: String(text[valueRange]))
    }

    static func firstTextMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
            let valueRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        let matchedText = text[valueRange].trimmingCharacters(in: .whitespacesAndNewlines)
        return matchedText.isEmpty ? nil : matchedText
    }

    static func servingSizeValue(from line: String) -> String? {
        firstTextMatch(in: line, pattern: "\\bserving\\s*size\\b[:\\s-]*(.+)$")
    }

    static func isPotentialProductName(_ line: String) -> Bool {
        guard isNutritionBlockLine(line) == false else { return false }
        guard line.rangeOfCharacter(from: .letters) != nil else { return false }
        return isPackagingCopyLine(line) == false
    }

    static func isServingSizeLine(_ line: String) -> Bool {
        containsPattern("\\bserving\\s*size\\b", in: line)
    }

    static func isServingSizeContinuation(_ line: String) -> Bool {
        guard isNutritionBlockLine(line) == false else { return false }
        guard isPackagingCopyLine(line) == false else { return false }
        return line.rangeOfCharacter(from: .letters) != nil || line.rangeOfCharacter(from: .decimalDigits) != nil
    }

    static func isNutrientValueContinuation(_ line: String) -> Bool {
        guard isNutritionBlockLine(line) == false else { return false }
        return containsPattern("^\\s*[<~]?\\s*\\d", in: line)
    }

    static func isAddedSugarsAmountLine(_ line: String) -> Bool {
        containsPattern("^\\s*includes\\b", in: line) && containsPattern("\\d", in: line)
    }

    static func isAddedSugarsLabelContinuation(_ line: String) -> Bool {
        containsPattern("^\\s*added\\s+sugars\\b", in: line)
    }

    static func isNutritionBlockLine(_ line: String) -> Bool {
        isNutritionHeader(line) || isNutritionMetadata(line) || isLikelyNutrientLine(line)
    }

    static func isNutritionHeader(_ line: String) -> Bool {
        containsPattern("\\bnutrition\\b", in: line) || containsPattern("\\bfacts\\b", in: line)
    }

    static func isNutritionMetadata(_ line: String) -> Bool {
        containsPattern("\\bserving\\s*size\\b", in: line)
            || containsPattern("\\bservings?\\s+per\\s+container\\b", in: line)
            || containsPattern("\\bamount\\s+per\\s+serving\\b", in: line)
            || containsPattern("%\\s*daily\\s+value", in: line)
    }

    static func isLikelyNutrientLine(_ line: String) -> Bool {
        let startsWithNutrientLabel =
            containsPattern("^\\s*calories\\b", in: line)
            || containsPattern("^\\s*protein\\b", in: line)
            || containsPattern("^\\s*total\\s+fat\\b", in: line)
            || containsPattern("^\\s*fat\\b", in: line)
            || containsPattern("^\\s*saturated\\s+fat\\b", in: line)
            || containsPattern("^\\s*total\\s+carbohydrates?\\b", in: line)
            || containsPattern("^\\s*carbohydrates?\\b", in: line)
            || containsPattern("^\\s*carbs?\\b", in: line)
            || containsPattern("^\\s*sodium\\b", in: line)
            || containsPattern("^\\s*cholesterol\\b", in: line)
            || containsPattern("^\\s*dietary\\s+fiber\\b", in: line)
            || containsPattern("^\\s*fiber\\b", in: line)
            || containsPattern("^\\s*total\\s+sugars\\b", in: line)
            || containsPattern("^\\s*sugars?\\b", in: line)
            || containsPattern("^\\s*includes\\b.*\\badded\\s+sugars\\b", in: line)
            || containsPattern("^\\s*added\\s+sugars\\b", in: line)
            || containsPattern("^\\s*potassium\\b", in: line)
            || containsPattern("^\\s*calcium\\b", in: line)
            || containsPattern("^\\s*iron\\b", in: line)

        guard startsWithNutrientLabel else { return false }

        return containsPattern("\\d", in: line) || isPlainNutrientLabelLine(line)
    }

    static func isPlainNutrientLabelLine(_ line: String) -> Bool {
        containsPattern(
            "^\\s*(?:calories|protein|total\\s+fat|fat|saturated\\s+fat|total\\s+carbohydrates?|carbohydrates?|carbs?|sodium|cholesterol|dietary\\s+fiber|fiber|total\\s+sugars|sugars?|added\\s+sugars|potassium|calcium|iron)\\s*[:*]*\\s*$",
            in: line
        )
    }

    static func isPackagingCopyLine(_ line: String) -> Bool {
        containsPattern("^\\s*net\\s+wt\\b", in: line)
            || containsPattern("^\\s*keep\\s+(?:frozen|refrigerated|cold)\\b", in: line)
            || containsPattern("^\\s*(?:perishable|shake\\s+well|best\\s+by|sell\\s+by|distributed\\s+by|ingredients\\b)", in: line)
    }

    static func containsPattern(_ pattern: String, in line: String) -> Bool {
        line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func parsedNumber(from text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ""))
    }

    static func amountPattern(labelPattern: String, unit: NutrientAmountUnit) -> String {
        "^\\s*\(labelPattern)\\b[^\\d]*\(capturedNumberPattern)\\s*\(unit.rawValue)\\b"
    }

    static func percentDailyValuePattern(labelPattern: String) -> String {
        "^\\s*\(labelPattern)\\b[^\\d%]*[<~]?\\s*\(capturedNumberPattern)\\s*%"
    }

    static func nutrientAmountFromPercentDailyValue(
        _ percentDailyValue: Double,
        dailyValueMilligrams: Double
    ) -> Double {
        (percentDailyValue / 100) * dailyValueMilligrams
    }

    static func notes(
        for draft: FoodDraft,
        servingDescriptionDetected: Bool,
        detectedNutrients: DetectedNutrients
    ) -> [String] {
        var notes: [String] = []

        if draft.name.isEmpty {
            notes.append("OCR could not confidently detect the food name. Add it before saving.")
        }

        if servingDescriptionDetected == false {
            notes.append("Serving size was not confidently detected. Review the label details before saving.")
        }

        if draft.gramsPerServing == nil {
            notes.append("Serving grams were not confidently detected. Gram-based logging will stay disabled until you add them.")
        }

        if detectedNutrients.calories == nil {
            notes.append("Calories were not confidently detected. Review the label values before saving.")
        }

        let missingMacroNames = missingMacroNames(from: detectedNutrients)
        if missingMacroNames.isEmpty == false {
            let missingMacrosMessage =
                "\(joinedList(missingMacroNames)) "
                + "\(missingMacroVerb(for: missingMacroNames.count)) "
                + "not confidently detected. Review the label values before saving."
            notes.append(missingMacrosMessage)
        }

        return notes
    }

    static func missingMacroNames(from nutrients: DetectedNutrients) -> [String] {
        nutrients.missingRequiredNutrients
            .filter { $0 != .calories }
            .map(\.displayName)
    }

    static func joinedList(_ values: [String]) -> String {
        switch values.count {
        case 0:
            return ""
        case 1:
            return values[0]
        case 2:
            return "\(values[0]) and \(values[1])"
        default:
            let prefix = values.dropLast().joined(separator: ", ")
            return "\(prefix), and \(values[values.count - 1])"
        }
    }

    static func missingMacroVerb(for count: Int) -> String {
        count == 1 ? "was" : "were"
    }
}
