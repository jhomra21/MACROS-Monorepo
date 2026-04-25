import Foundation

struct NutritionLabelParseResult {
    let draft: FoodDraft
    let notes: [String]
    let missingRequiredNutrients: [RequiredNutritionReviewNutrient]
}

enum NutritionLabelParser {
    static func reviewRequiredNutrientsMessage(_ nutrients: [RequiredNutritionReviewNutrient]) -> String {
        let nutrientNames = joinedList(nutrients.map(\.displayName))
        return
            "\(nutrientNames) were not confidently detected. Edit those values before logging, "
            + "or confirm that any remaining 0 values are intentional."
    }

    static func parse(recognizedText: NutritionLabelRecognizedText) -> NutritionLabelParseResult {
        let parsedText = ParsedLabelText(recognizedText: recognizedText)
        let detectedServingDescription = servingDescription(from: parsedText)
        let detectedNutrients = detectedNutrients(from: parsedText.nutritionLines)
        let draft = FoodDraft(
            importedData: FoodDraftImportedData(
                name: inferredName(from: parsedText),
                source: .labelScan,
                servingDescription: detectedServingDescription ?? FoodDraft.defaultServingDescription,
                gramsPerServing: gramsPerServing(from: parsedText),
                perServingNutrition: detectedNutrients.perServingNutritionValues
            )
        )

        return NutritionLabelParseResult(
            draft: draft,
            notes: notes(
                for: draft,
                servingDescriptionDetected: detectedServingDescription != nil,
                detectedNutrients: detectedNutrients
            ),
            missingRequiredNutrients: detectedNutrients.missingRequiredNutrients
        )
    }

    private static func detectedNutrients(from lines: [String]) -> DetectedNutrients {
        DetectedNutrients(
            calories: nutrientValue(
                matching: ["^\\s*calories\\b(?!\\s+from\\s+fat\\b)[^\\d]*\(capturedNumberPattern)"],
                in: lines
            ),
            protein: nutrientValue(
                matching: [amountPattern(labelPattern: "protein", unit: .grams)],
                in: lines
            ),
            fat: nutrientValue(
                matching: [
                    amountPattern(labelPattern: "total\\s+fat", unit: .grams),
                    amountPattern(labelPattern: "fat", unit: .grams)
                ],
                in: lines
            ),
            carbs: nutrientValue(
                matching: [
                    amountPattern(labelPattern: "total\\s+carbohydrates?", unit: .grams),
                    amountPattern(labelPattern: "carbohydrates?", unit: .grams),
                    amountPattern(labelPattern: "carbs?", unit: .grams)
                ],
                in: lines
            ),
            saturatedFat: nutrientValue(
                matching: [amountPattern(labelPattern: "saturated\\s+fat", unit: .grams)],
                in: lines
            ),
            fiber: nutrientValue(
                matching: [
                    amountPattern(labelPattern: "dietary\\s+fiber", unit: .grams),
                    amountPattern(labelPattern: "fiber", unit: .grams)
                ],
                in: lines
            ),
            sugars: nutrientValue(
                matching: [
                    amountPattern(labelPattern: "total\\s+sugars", unit: .grams),
                    amountPattern(labelPattern: "sugars?", unit: .grams)
                ],
                in: lines
            ),
            addedSugars: nutrientValue(
                matching: [
                    "^\\s*includes\\b[^\\d]*\(capturedNumberPattern)\\s*g\\b\\s+added\\s+sugars\\b",
                    amountPattern(labelPattern: "added\\s+sugars", unit: .grams)
                ],
                in: lines
            ),
            sodium: nutrientValue(
                matching: [amountPattern(labelPattern: "sodium", unit: .milligrams)],
                orPercentDailyValueFor: .sodium,
                in: lines
            ),
            cholesterol: nutrientValue(
                matching: [amountPattern(labelPattern: "cholesterol", unit: .milligrams)],
                orPercentDailyValueFor: .cholesterol,
                in: lines
            )
        )
    }

    private static func inferredName(from parsedText: ParsedLabelText) -> String {
        let candidates = parsedText.lines[..<parsedText.nutritionBlockStartIndex]
            .filter { line in
                isPotentialProductName(line)
            }
        return candidates.last ?? ""
    }

    private static func servingDescription(from parsedText: ParsedLabelText) -> String? {
        for (index, line) in parsedText.lines.enumerated() {
            guard isServingSizeLine(line) else { continue }

            let continuations = servingSizeContinuations(after: index, in: parsedText.lines)
            if let inlineValue = servingSizeValue(from: line), inlineValue.isEmpty == false {
                if continuations.isEmpty == false {
                    return ([line] + continuations).joined(separator: " ")
                }
                return line
            }

            if continuations.isEmpty == false {
                return ([line] + continuations).joined(separator: " ")
            }
        }

        return nil
    }

    private static func gramsPerServing(from parsedText: ParsedLabelText) -> Double? {
        for index in parsedText.lines.indices where isServingSizeLine(parsedText.lines[index]) {
            for candidate in servingSizeCandidateTexts(at: index, in: parsedText.lines) {
                if let grams = servingGrams(in: candidate) {
                    return grams
                }
            }
        }

        return nil
    }

    private static func nutrientValue(matching patterns: [String], in lines: [String]) -> Double? {
        nutrientValue(matching: patterns, orPercentDailyValueFor: nil, in: lines)
    }

    private static func nutrientValue(
        matching patterns: [String],
        orPercentDailyValueFor nutrient: PercentDailyValueNutrient?,
        in lines: [String]
    ) -> Double? {
        for index in lines.indices {
            for candidate in nutrientCandidateTexts(at: index, in: lines) {
                for pattern in patterns {
                    if let value = firstMatch(in: candidate, pattern: pattern) {
                        return value
                    }
                }

                if let nutrient,
                    let percentDailyValue = firstMatch(
                        in: candidate,
                        pattern: percentDailyValuePattern(labelPattern: nutrient.labelPattern)
                    )
                {
                    return nutrientAmountFromPercentDailyValue(
                        percentDailyValue,
                        dailyValueMilligrams: nutrient.dailyValueMilligrams
                    )
                }
            }
        }

        return nil
    }

    private static func servingGrams(in text: String) -> Double? {
        firstMatch(in: text, pattern: "\\(\(capturedNumberPattern)\\s*g\\)")
            ?? firstMatch(in: text, pattern: "\\b\(capturedNumberPattern)\\s*g\\b")
    }

    private static func servingSizeContinuations(after index: Int, in lines: [String]) -> [String] {
        var continuations: [String] = []
        var nextIndex = lines.index(after: index)

        while nextIndex < lines.endIndex {
            let continuation = lines[nextIndex]
            guard isServingSizeContinuation(continuation) else { break }
            continuations.append(continuation)
            nextIndex = lines.index(after: nextIndex)
        }

        return continuations
    }

    private static func servingSizeCandidateTexts(at index: Int, in lines: [String]) -> [String] {
        let line = lines[index]
        let continuations = servingSizeContinuations(after: index, in: lines)
        guard continuations.isEmpty == false else { return [line] }

        var candidates = [line]
        var combinedLine = line
        for continuation in continuations {
            combinedLine += " \(continuation)"
            candidates.append(combinedLine)
        }

        return candidates
    }

    private static func nutrientCandidateTexts(at index: Int, in lines: [String]) -> [String] {
        let line = lines[index]
        let nextIndex = lines.index(after: index)
        guard nextIndex < lines.endIndex else { return [line] }

        let nextLine = lines[nextIndex]
        if containsPattern("\\d", in: line) == false {
            guard isNutrientValueContinuation(nextLine) else { return [line] }
            return ["\(line) \(nextLine)"]
        }

        if isAddedSugarsAmountLine(line), isAddedSugarsLabelContinuation(nextLine) {
            return ["\(line) \(nextLine)", line]
        }

        return [line]
    }
}
