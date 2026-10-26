import XCTest
import SwiftData
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

        XCTAssertEqual(results.map(\.name), ["Chicken Breast", "Almond Chicken", "Chicken And Vegetable Entree With Noodles"])
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
        XCTAssertEqual(steakResults.first?.name, "Steak Sauce")
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
        let creamSoda = makeFood(name: "Soft Drink, Cream Soda", calories: 151, aliases: ["soda"])
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

    func testEverydayQueriesPreferPlainFoodOverCompoundAndModifierMatches() {
        let foods = [
            makeFood(name: "Rice Croquette", calories: 154),
            makeFood(name: "White Rice", calories: 205, aliases: ["rice", "white rice"]),
            makeFood(name: "Pancake Syrup", calories: 53),
            makeFood(name: "Chinese Pancake", calories: 207),
            makeFood(name: "Pancakes, Plain", calories: 186, aliases: ["pancake"]),
            makeFood(name: "Chicken Cornbread", calories: 154),
            makeFood(name: "Chicken Breast", calories: 128, aliases: ["chicken"]),
            makeFood(name: "Bread Stuffing", calories: 266),
            makeFood(name: "Bread, Whole Wheat", calories: 80),
            makeFood(name: "Water Chesnut", calories: 123),
            makeFood(name: "Water, Tap", calories: 0),
            makeFood(name: "Veggie Burger", calories: 224),
            makeFood(name: "Hamburger", calories: 250, aliases: ["burger"]),
            makeFood(name: "Beef Salad", calories: 475),
            makeFood(name: "Mixed Salad Greens", calories: 20, aliases: ["salad"])
        ]

        let expectedFirstResults = [
            ("rice", "White Rice"),
            ("pancake", "Pancakes, Plain"),
            ("chicken", "Chicken Breast"),
            ("bread", "Bread, Whole Wheat"),
            ("water", "Water, Tap"),
            ("burger", "Hamburger"),
            ("salad", "Mixed Salad Greens")
        ]

        for (query, expectedName) in expectedFirstResults {
            XCTAssertEqual(
                FoodItemLocalSearch.rankedFoods(foods, matching: query).first?.name,
                expectedName,
                "Unexpected first result for \(query)"
            )
        }
    }

    func testStaplePrioritiesOverrideArbitraryTieBreakersWithinMatchTier() throws {
        let foods = [
            makeFood(name: "Milk, Dry", calories: 10),
            makeFood(name: "Milk, Whole", calories: 19),
            makeFood(name: "Oatmeal, Fast Food", calories: 192),
            makeFood(name: "Oatmeal, Regular Or Quick, No Added Fat", calories: 109),
            makeFood(name: "Bread, Egg", calories: 89),
            makeFood(name: "Bread, White", calories: 80),
            makeFood(name: "Beef, Rice", calories: 241),
            makeFood(name: "Beef, Ground", calories: 250),
            makeFood(name: "Turkey, Back", calories: 203),
            makeFood(name: "Turkey, Light Meat, Roasted, Skin Not Eaten", calories: 135),
            makeFood(name: "Pancakes, Fruit", calories: 224),
            makeFood(name: "Pancakes, Plain", calories: 233),
            makeFood(name: "Rice Croquette", calories: 154),
            makeFood(name: "White Rice", calories: 205, aliases: ["rice"]),
            makeFood(name: "Chicken Cornbread", calories: 154),
            makeFood(name: "Chicken Breast", calories: 128, aliases: ["chicken"]),
            makeFood(name: "Beef Salad", calories: 475),
            makeFood(name: "Mixed Salad Greens, Raw", calories: 20, aliases: ["salad"]),
            makeFood(name: "Sushi Roll Tuna", calories: 145),
            makeFood(name: "Fish, Tuna", calories: 133, aliases: ["tuna"])
        ]
        let priorities = [
            "Milk, Whole": 1,
            "Oatmeal, Regular Or Quick, No Added Fat": 2,
            "Bread, White": 3,
            "Beef, Ground": 4,
            "Turkey, Light Meat, Roasted, Skin Not Eaten": 5,
            "Pancakes, Plain": 6,
            "White Rice": 7,
            "Chicken Breast": 8,
            "Mixed Salad Greens, Raw": 9,
            "Fish, Tuna": 10
        ]
        let expectedFirstResults = [
            ("milk", "Milk, Whole"),
            ("oatmeal", "Oatmeal, Regular Or Quick, No Added Fat"),
            ("bread", "Bread, White"),
            ("beef", "Beef, Ground"),
            ("turkey", "Turkey, Light Meat, Roasted, Skin Not Eaten"),
            ("pancake", "Pancakes, Plain"),
            ("rice", "White Rice"),
            ("chicken", "Chicken Breast"),
            ("salad", "Mixed Salad Greens, Raw"),
            ("tuna", "Fish, Tuna")
        ]

        let cannedTuna = try XCTUnwrap(foods.first(where: { $0.name == "Fish, Tuna" }))
        XCTAssertEqual(
            FoodItemLocalSearch.rank(for: cannedTuna, matching: FoodItemSearchQuery("tuna")),
            0,
            cannedTuna.searchableText.debugDescription
        )

        for (query, expectedName) in expectedFirstResults {
            XCTAssertEqual(
                FoodItemLocalSearch.rankedFoods(foods, matching: query, priorities: priorities).first?.name,
                expectedName,
                "Unexpected first result for \(query)"
            )
        }
    }

    func testBundledManifestPrioritiesRankWholeMilkBeforeDryMilk() {
        let priorities = CommonFoodSeedLoader.staplePriorities
        let foods = [
            makeFood(name: "Milk, Dry", calories: 10),
            makeFood(name: "Milk, Whole", calories: 19)
        ]

        XCTAssertEqual(priorities["Milk, Whole"], 1)
        XCTAssertEqual(
            FoodItemLocalSearch.rankedFoods(foods, matching: "milk", priorities: priorities).first?.name,
            "Milk, Whole"
        )
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

    @MainActor
    func testFetchAndRankFindsFoldedTermsInBothFoodSearchSurfaces() throws {
        let container = try ModelContainer(
            for: FoodItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = container.mainContext
        let foods = [
            makeFood(name: "Cherries, Raw", calories: 50),
            makeFood(name: "Pancakes, Plain", calories: 233, aliases: ["pancake"]),
            makeFood(name: "Cottage Cheese, Farmer's", calories: 98),
            makeFood(name: "Soy-based beverage", calories: 41),
            makeFood(name: "Peppers, Sweet, Raw", calories: 34, aliases: ["bell pepper"]),
        ]
        foods.forEach(context.insert)
        try context.save()

        let expectations = [
            ("cherry", "Cherries, Raw"),
            ("pancake", "Pancakes, Plain"),
            ("farmer's", "Cottage Cheese, Farmer's"),
            ("soy-based", "Soy-based beverage"),
            ("bell pepper", "Peppers, Sweet, Raw"),
        ]

        for (query, expectedName) in expectations {
            let addFoodResults = try localFoodCandidates(in: context, matching: query)
            XCTAssertEqual(
                FoodItemLocalSearch.rankedFoods(addFoodResults, matching: query).first?.name,
                expectedName,
                "Add Food search did not find \(query)"
            )
            XCTAssertEqual(
                try pickerLocalFoodCandidates(in: context, query: query).first?.name,
                expectedName,
                "Meal component picker did not find \(query)"
            )
        }
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
