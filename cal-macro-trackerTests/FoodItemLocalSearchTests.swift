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

    func testWholeWordMatchesRankBeforeSubstringMatches() {
        let watercress = makeFood(name: "Watercress", calories: 4)
        let tapWater = makeFood(name: "Water, Tap", calories: 0)
        let limburger = makeFood(name: "Cheese, Limburger", calories: 742)
        let veggieBurger = makeFood(name: "Veggie Burger Patty", calories: 221)
        let steakSauce = makeFood(name: "Steak Sauce", calories: 16)
        let beefSteak = makeFood(name: "Beef, Steak", calories: 45)

        let waterResults = FoodItemLocalSearch.rankedFoods([watercress, tapWater], matching: "water")
        let burgerResults = FoodItemLocalSearch.rankedFoods([limburger, veggieBurger], matching: "burger")
        let steakResults = FoodItemLocalSearch.rankedFoods([steakSauce, beefSteak], matching: "steak")

        XCTAssertEqual(waterResults.first?.name, "Water, Tap")
        XCTAssertEqual(burgerResults.first?.name, "Veggie Burger Patty")
        XCTAssertEqual(steakResults.first?.name, "Beef, Steak")
    }

    func testModifierFoodsRankAfterUnmodifiedFoods() {
        let coffeeSubstitute = makeFood(name: "Coffee Substitute", calories: 14)
        let brewedCoffee = makeFood(name: "Coffee, Brewed", calories: 5)
        let pancakeSyrup = makeFood(name: "Pancake Syrup", calories: 53)
        let pancakes = makeFood(name: "Pancakes, Plain", calories: 186)
        let potatoChips = makeFood(name: "Potato Chips", calories: 267)
        let potato = makeFood(name: "Potato, Baked", calories: 265)
        let condensedMilk = makeFood(name: "Milk, Condensed", calories: 976)
        let wholeMilk = makeFood(name: "Milk, Whole", calories: 37)
        let riceCake = makeFood(name: "Rice Cake", calories: 176)
        let whiteRice = makeFood(name: "White Rice", calories: 204)
        let breadStuffing = makeFood(name: "Bread Stuffing", calories: 266)
        let barleyBread = makeFood(name: "Bread, Barley", calories: 77)
        let sodaBread = makeFood(name: "Bread, Irish Soda", calories: 222)
        let creamSoda = makeFood(name: "Soft Drink, Cream Soda", calories: 151)
        let waterChestnut = makeFood(name: "Water Chesnut", calories: 123)
        let bottledWater = makeFood(name: "Water, Bottled", calories: 0)

        let coffeeResults = FoodItemLocalSearch.rankedFoods([coffeeSubstitute, brewedCoffee], matching: "coffee")
        let pancakeResults = FoodItemLocalSearch.rankedFoods([pancakeSyrup, pancakes], matching: "pancake")
        let potatoResults = FoodItemLocalSearch.rankedFoods([potatoChips, potato], matching: "potato")
        let milkResults = FoodItemLocalSearch.rankedFoods([condensedMilk, wholeMilk], matching: "milk")
        let riceResults = FoodItemLocalSearch.rankedFoods([riceCake, whiteRice], matching: "rice")
        let breadResults = FoodItemLocalSearch.rankedFoods([breadStuffing, barleyBread], matching: "bread")
        let sodaResults = FoodItemLocalSearch.rankedFoods([sodaBread, creamSoda], matching: "soda")
        let waterResults = FoodItemLocalSearch.rankedFoods([waterChestnut, bottledWater], matching: "water")

        XCTAssertEqual(coffeeResults.first?.name, "Coffee, Brewed")
        XCTAssertEqual(pancakeResults.first?.name, "Pancakes, Plain")
        XCTAssertEqual(potatoResults.first?.name, "Potato, Baked")
        XCTAssertEqual(milkResults.first?.name, "Milk, Whole")
        XCTAssertEqual(riceResults.first?.name, "White Rice")
        XCTAssertEqual(breadResults.first?.name, "Bread, Barley")
        XCTAssertEqual(sodaResults.first?.name, "Soft Drink, Cream Soda")
        XCTAssertEqual(waterResults.first?.name, "Water, Bottled")
    }

    func testPunctuationAndDiacriticsShareSearchTokenization() {
        let farmersCheese = makeFood(name: "Cottage Cheese, Farmer's", calories: 98)
        let soyBasedFood = makeFood(name: "Soy-based beverage", calories: 41)
        let cafe = makeFood(name: "Café Latte", calories: 130)

        XCTAssertEqual(FoodItemLocalSearch.rankedFoods([farmersCheese], matching: "farmer's").first?.name, farmersCheese.name)
        XCTAssertEqual(FoodItemLocalSearch.rankedFoods([soyBasedFood], matching: "soy-based").first?.name, soyBasedFood.name)
        XCTAssertEqual(FoodItemLocalSearch.rankedFoods([cafe], matching: "cafe").first?.name, cafe.name)
        XCTAssertEqual(FoodItemSearchQuery("soy-based").tokens, ["soy", "based"])
        XCTAssertEqual(FoodItemSearchQuery("farmer's").tokens, ["farmer", "s"])
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
