import XCTest
@testable import cal_macro_tracker

@MainActor
final class MealPhotoTests: XCTestCase {
    // MARK: Response parser

    private func response(status: String = "ok", foods: String = "[]") -> Data {
        Data(#"{"requestId":"r1","model":"gemini-3.5-flash-lite","status":"\#(status)","foods":\#(foods)}"#.utf8)
    }

    func testParsesTypicalPlate() throws {
        let estimate = try MealPhotoResponseParser.parse(
            response(
                foods: #"""
                    [{"name":" Grilled chicken ","grams":150.5,"lowGrams":120,"highGrams":180,"preparation":"grilled","hiddenFatLikely":true,"volumeMl":null},
                     {"name":"Rice","grams":null,"lowGrams":null,"highGrams":null,"preparation":null,"hiddenFatLikely":false,"volumeMl":200}]
                    """#))
        XCTAssertEqual(estimate.requestID, "r1")
        XCTAssertEqual(estimate.status, .ok)
        XCTAssertEqual(estimate.foods.map(\.name), ["Grilled chicken", "Rice"])
        XCTAssertEqual(estimate.foods[0].grams, 150.5)
        XCTAssertTrue(estimate.foods[0].hiddenFatLikely)
        XCTAssertNil(estimate.foods[1].grams)
        XCTAssertEqual(estimate.foods[1].volumeMl, 200)
    }

    func testDropsInvalidFoodsAndClampsGrams() throws {
        let estimate = try MealPhotoResponseParser.parse(
            response(
                foods: #"""
                    [{"name":"","grams":50},{"grams":50},{"name":"Zero","grams":0},{"name":"Negative","grams":-5},
                     {"name":"Huge","grams":99999},{"name":123,"grams":10},{"name":"Fine","grams":"12"}]
                    """#))
        XCTAssertEqual(estimate.foods.map(\.name), ["Zero", "Negative", "Huge", "Fine"])
        XCTAssertEqual(estimate.foods.map(\.grams), [nil, nil, 3_000, nil])
    }

    func testKeepsAtMostFifteenFoods() throws {
        let foods = (1...20).map { #"{"name":"Food \#($0)","grams":10}"# }.joined(separator: ",")
        let estimate = try MealPhotoResponseParser.parse(response(foods: "[\(foods)]"))
        XCTAssertEqual(estimate.foods.count, 15)
        XCTAssertEqual(estimate.foods.last?.name, "Food 15")
    }

    func testNonOkStatusesCarryNoFoods() throws {
        for status in ["not_food", "unclear", "packaged"] {
            let estimate = try MealPhotoResponseParser.parse(response(status: status, foods: #"[{"name":"Apple","grams":5}]"#))
            XCTAssertEqual(estimate.status.rawValue, status)
            XCTAssertTrue(estimate.foods.isEmpty)
        }
    }

    func testRejectsMalformedResponses() {
        let bad = [
            "", "not json", "{}", #"{"requestId":"r","model":"m","status":"weird","foods":[]}"#,
            #"{"requestId":"","model":"m","status":"ok","foods":[]}"#, #"{"model":"m","status":"ok"}"#
        ]
        for json in bad {
            XCTAssertThrowsError(try MealPhotoResponseParser.parse(Data(json.utf8)), json)
        }
    }

    func testDebugFixturesParse() throws {
        XCTAssertEqual(try MealPhotoMockFixtures.response(named: "typical-plate").foods.count, 3)
        XCTAssertEqual(try MealPhotoMockFixtures.response(named: "not-food").status, .notFood)
        let drink = try MealPhotoMockFixtures.response(named: "volume-only-drink")
        XCTAssertNil(drink.foods[0].grams)
        XCTAssertEqual(drink.foods[0].volumeMl, 250)
        XCTAssertThrowsError(try MealPhotoMockFixtures.response(named: "error"))
    }

    func testClientMapsFailures() {
        XCTAssertEqual(MealPhotoClient.error(forStatus: 429, body: "daily_limit"), .dailyLimit)
        XCTAssertEqual(MealPhotoClient.error(forStatus: 429, body: "rate_limited"), .rateLimited)
        XCTAssertEqual(MealPhotoClient.error(forStatus: 504, body: "upstream_timeout"), .timeout)
        XCTAssertEqual(MealPhotoClient.error(forStatus: 502, body: nil), .unavailable)
        XCTAssertEqual(MealPhotoClient.error(for: URLError(.notConnectedToInternet)), .offline)
        XCTAssertFalse(MealPhotoError.dailyLimit.canRetry)
    }

    // MARK: Trial

    func testTrialCounting() {
        XCTAssertEqual(MealPhotoTrial.remaining(used: 0), 5)
        XCTAssertEqual(MealPhotoTrial.remaining(used: 4), 1)
        XCTAssertEqual(MealPhotoTrial.remaining(used: 5), 0)
        XCTAssertEqual(MealPhotoTrial.remaining(used: 99), 0)
        XCTAssertTrue(MealPhotoTrial.canScan(hasPro: false, used: 4))
        XCTAssertFalse(MealPhotoTrial.canScan(hasPro: false, used: 5))
        XCTAssertTrue(MealPhotoTrial.canScan(hasPro: true, used: 5))
        XCTAssertEqual(MealPhotoTrial.used(afterSuccessfulScan: 2, hasPro: false), 3)
        XCTAssertEqual(MealPhotoTrial.used(afterSuccessfulScan: 5, hasPro: false), 5)
        XCTAssertEqual(MealPhotoTrial.used(afterSuccessfulScan: 2, hasPro: true), 2)
    }

    // MARK: Grams to nutrition

    private func food(name: String = "Rice", servingGrams: Double?, calories: Double = 200) -> FoodDraft {
        var draft = FoodDraft()
        draft.name = name
        draft.servingDescription = "1 cup"
        draft.gramsPerServing = servingGrams
        draft.caloriesPerServing = calories
        draft.proteinPerServing = 4
        draft.carbsPerServing = 40
        draft.fatPerServing = 1
        return draft
    }

    func testGramsScaleFromGramWeightedFood() {
        let item = MealPhotoItem.suggested(MealPhotoSuggestedFood(name: "Rice", grams: 79), food: food(servingGrams: 158))
        XCTAssertEqual(item.quantityMode, .grams)
        XCTAssertEqual(item.amount, 79)
        XCTAssertEqual(item.nutrients.calories, 100, accuracy: 0.0001)
        XCTAssertEqual(item.nutrients.carbs, 20, accuracy: 0.0001)
        XCTAssertEqual(item.loggingAction?.quantityMultiplier ?? 0, 0.5, accuracy: 0.0001)
    }

    func testServingsOnlyFoodNeedsUserQuantity() {
        let item = MealPhotoItem.suggested(MealPhotoSuggestedFood(name: "Rice", grams: 150), food: food(servingGrams: nil))
        XCTAssertEqual(item.quantityMode, .servings)
        XCTAssertNil(item.amount, "Grams must not be converted without a gram weight")
        XCTAssertFalse(item.isReadyToLog)
        XCTAssertNil(item.loggingAction)
        var confirmed = item
        confirmed.amount = 1.5
        XCTAssertEqual(confirmed.nutrients.calories, 300, accuracy: 0.0001)
        XCTAssertNil(confirmed.gramsEaten)
    }

    func testVolumeOnlySuggestionGetsNoInventedGrams() {
        let drink = MealPhotoSuggestedFood(name: "Orange juice", grams: nil, volumeMl: 250)
        let item = MealPhotoItem.suggested(drink, food: food(name: "Orange juice", servingGrams: 248))
        XCTAssertNil(item.amount)
        XCTAssertFalse(item.isReadyToLog)
    }

    func testReplacingFoodCarriesGramsOnlyToGramWeightedFoods() {
        var item = MealPhotoItem.suggested(MealPhotoSuggestedFood(name: "Rice", grams: 120), food: food(servingGrams: 100))
        item.amount = 90
        item.replaceFood(with: food(name: "Other", servingGrams: 50))
        XCTAssertEqual(item.amount, 90)
        item.replaceFood(with: food(name: "Servings only", servingGrams: nil))
        XCTAssertNil(item.amount)
        item.amount = 2
        item.replaceFood(with: food(name: "Back", servingGrams: 100))
        XCTAssertEqual(item.amount, 120, "Falls back to the suggested grams, not servings treated as grams")
    }

    func testOilItemIsEditableTablespoon() {
        let oil = MealPhotoItem.oil(matching: nil)
        XCTAssertEqual(oil.origin, .oil)
        XCTAssertEqual(oil.amount, 14)
        XCTAssertEqual(oil.nutrients.calories, 126, accuracy: 0.0001)
    }

    // MARK: Feedback calculator

    private func feedback(
        suggested: [MealPhotoSuggestedFood], final: [MealPhotoItem], answer: MealPhotoHiddenFatAnswer = .skipped
    ) -> MealPhotoFeedback {
        .make(requestID: "r1", model: "m", suggested: suggested, final: final, hiddenFatAnswer: answer)
    }

    func testFeedbackCountsKeptEditedRemovedAndAdded() {
        let a = MealPhotoSuggestedFood(name: "A", grams: 100)
        let b = MealPhotoSuggestedFood(name: "B", grams: 200)
        let c = MealPhotoSuggestedFood(name: "C", grams: 50)
        let d = MealPhotoSuggestedFood(name: "D", grams: 80)
        let rice = food(servingGrams: 100)
        let itemA = MealPhotoItem.suggested(a, food: rice)
        var itemB = MealPhotoItem.suggested(b, food: rice)
        itemB.amount = 300
        var itemC = MealPhotoItem.suggested(c, food: rice)
        itemC.amount = 40
        let added = MealPhotoItem.added(food: rice)
        let result = feedback(suggested: [a, b, c, d], final: [itemA, itemB, itemC, added, .oil(matching: nil)], answer: .yes)
        XCTAssertEqual(result.suggested, 4)
        XCTAssertEqual(result.keptUnchanged, 1)
        XCTAssertEqual(result.gramsEdited, 2)
        XCTAssertEqual(result.removed, 1)
        XCTAssertEqual(result.added, 1, "The oil item is reported through the hidden fat answer")
        XCTAssertEqual(result.medianGramChangePct ?? 0, 35, accuracy: 0.0001)  // +50% and -20%: median of |50|, |20|
        XCTAssertEqual(result.hiddenFatAnswer, .yes)
    }

    func testFeedbackWithNoEditsHasNullMedian() throws {
        let a = MealPhotoSuggestedFood(name: "A", grams: 100)
        let result = feedback(suggested: [a], final: [MealPhotoItem.suggested(a, food: food(servingGrams: 100))])
        XCTAssertNil(result.medianGramChangePct)
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(result), encoding: .utf8))
        XCTAssertTrue(json.contains(#""medianGramChangePct":null"#), json)
        XCTAssertFalse(json.contains("name"), "Feedback must not contain food names")
    }

    func testVolumeOnlyConfirmationCountsAsEditWithoutPercentage() {
        let drink = MealPhotoSuggestedFood(name: "Juice", grams: nil, volumeMl: 250)
        var item = MealPhotoItem.suggested(drink, food: food(servingGrams: 248))
        item.amount = 248
        let result = feedback(suggested: [drink], final: [item])
        XCTAssertEqual(result.gramsEdited, 1)
        XCTAssertNil(result.medianGramChangePct)
    }
}
