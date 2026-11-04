import XCTest
@testable import cal_macro_tracker

final class UnifiedFoodSearchParityTests: XCTestCase {
    private struct Fixture: Decodable {
        let name: String
        let product: OpenFoodFactsProduct
        let expected: Expected
    }

    private struct Expected: Decodable {
        let servingDescription: String
        let gramsPerServing: Double?
        let nutrition: [String: Double]
        let requiredReviewNutrients: [String]
    }

    @MainActor
    func testBarcodeMappingMatchesSharedCompleteNutritionVectors() throws {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: "UnifiedFoodSearchParity", withExtension: "json", subdirectory: "Fixtures")
                ?? bundle.url(forResource: "UnifiedFoodSearchParity", withExtension: "json")
        )
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
        for fixture in fixtures where fixture.expected.requiredReviewNutrients.isEmpty {
            let draft = try BarcodeLookupMapper.makeDraft(from: fixture.product, source: .searchLookup)
            XCTAssertEqual(draft.servingDescription, fixture.expected.servingDescription, fixture.name)
            XCTAssertEqual(draft.gramsPerServing, fixture.expected.gramsPerServing, fixture.name)
            XCTAssertEqual(draft.caloriesPerServing, fixture.expected.nutrition["calories"], fixture.name)
            XCTAssertEqual(draft.proteinPerServing, fixture.expected.nutrition["protein"], fixture.name)
            XCTAssertEqual(draft.fatPerServing, fixture.expected.nutrition["fat"], fixture.name)
            XCTAssertEqual(draft.carbsPerServing, fixture.expected.nutrition["carbs"], fixture.name)
            XCTAssertEqual(draft.sodiumPerServing, fixture.expected.nutrition["sodium"], fixture.name)
            XCTAssertEqual(draft.cholesterolPerServing, fixture.expected.nutrition["cholesterol"], fixture.name)
        }
    }

    @MainActor
    func testUnknownSourceDecodesWithoutProviderSwitchAndRequiresMissingValues() throws {
        let json = """
            {"id":"future:123","source":"future","externalProductID":"future:123","name":"Food",
            "servingDescription":"100 g","gramsPerServing":100,"nutrition":{"calories":100,"protein":20},
            "requiredReviewNutrients":["fat","carbs"]}
            """
        let result = try JSONDecoder().decode(RemoteSearchResult.self, from: Data(json.utf8))
        XCTAssertEqual(result.id, "future:123")
        XCTAssertEqual(result.requiredReviewNutrients, [.fat, .carbs])
        XCTAssertEqual(result.makeDraft().externalProductID, "future:123")
        XCTAssertEqual(result.reviewNotes, ["Check the values before logging."])
    }

    @MainActor
    func testNewerQueryWinsEvenWhenOldTransportIgnoresCancellation() async throws {
        let result = try JSONDecoder().decode(
            RemoteSearchResult.self,
            from: Data("""
                {"id":"future:1","source":"future","externalProductID":"future:1","name":"Chicken breast",
                "servingDescription":"100 g","nutrition":{"calories":100,"protein":20,"fat":2,"carbs":0},
                "requiredReviewNutrients":[]}
                """.utf8)
        )
        var releaseOld: CheckedContinuation<FoodSearchPage, Never>?
        let session = FoodSearchSession { query, _ in
            if query == "chicken" {
                return await withCheckedContinuation { releaseOld = $0 }
            }
            return FoodSearchPage(query: query, results: [result], nextCursor: nil)
        }
        let old = Task { await session.load(query: "chicken", debounce: false) }
        await Task.yield()
        await session.load(query: "chicken breast", debounce: false)
        releaseOld?.resume(returning: FoodSearchPage(query: "chicken", results: [], nextCursor: nil))
        await old.value
        XCTAssertEqual(session.query, "chicken breast")
        XCTAssertEqual(session.results.map(\.id), ["future:1"])
        XCTAssertFalse(session.didFail)
    }

    @MainActor
    func testShortQueriesDoNotCallTransportAndErrorsAreRetryableWithoutServiceText() async {
        var calls = 0
        let session = FoodSearchSession { query, _ in
            calls += 1
            if calls == 1 { throw URLError(.cannotConnectToHost) }
            return FoodSearchPage(query: query, results: [], nextCursor: nil)
        }
        await session.load(query: "zz", debounce: false)
        XCTAssertEqual(calls, 0)
        await session.load(query: "chicken", debounce: false)
        XCTAssertTrue(session.didFail)
        await session.load(query: "chicken", debounce: false)
        XCTAssertFalse(session.didFail)
        XCTAssertEqual(calls, 2)
    }

    @MainActor
    func testCancelledDebounceDoesNotCallTransport() async {
        var calls = 0
        let session = FoodSearchSession { query, _ in
            calls += 1
            return FoodSearchPage(query: query, results: [], nextCursor: nil)
        }
        let task = Task { await session.load(query: "chicken") }
        await Task.yield()
        task.cancel()
        await task.value
        XCTAssertEqual(calls, 0)
    }
}
