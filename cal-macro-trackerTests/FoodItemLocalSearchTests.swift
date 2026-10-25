import XCTest
@testable import cal_macro_tracker

final class FoodItemLocalSearchTests: XCTestCase {
    func testGenericQueryRanksShortCanonicalFoodBeforeLongPreparedDishNames() {
        let preparedDish = makeFood(name: "Chicken And Vegetable Entree With Noodles", calories: 352)
        let chickenAlmonds = makeFood(name: "Almond Chicken", calories: 471)
        let chickenBreast = makeFood(name: "Chicken Breast", calories: 173, aliases: ["chicken", "chicken breast"])

        let results = FoodItemLocalSearch.rankedFoods(
            [preparedDish, chickenAlmonds, chickenBreast],
            matching: "chicken"
        )

        XCTAssertEqual(results.map(\.name), ["Chicken Breast", "Chicken And Vegetable Entree With Noodles", "Almond Chicken"])
    }

    func testExactFoodNameStillRanksBeforeOtherPrefixMatches() {
        let plainMilk = makeFood(name: "Milk", calories: 149)
        let milkShake = makeFood(name: "Milk Shake With Malt", calories: 350)

        let results = FoodItemLocalSearch.rankedFoods([milkShake, plainMilk], matching: "milk")

        XCTAssertEqual(results.map(\.name), ["Milk", "Milk Shake With Malt"])
    }

    private func makeFood(name: String, calories: Double, aliases: [String] = []) -> FoodItem {
        FoodItem(
            name: name,
            source: .common,
            servingDescription: "1 serving",
            caloriesPerServing: calories,
            proteinPerServing: 1,
            fatPerServing: 1,
            carbsPerServing: 1,
            aliases: aliases
        )
    }
}
