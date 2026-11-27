#if DEBUG
import Foundation

/// Stand-ins for the Worker while it is not deployed. Active only with the launch argument
/// `-MealPhotoMockResponse <typical-plate|not-food|volume-only-drink|error>`.
enum MealPhotoMockFixtures {
    static var requestedName: String? {
        UserDefaults.standard.string(forKey: "MealPhotoMockResponse")
    }

    static func response(named name: String) throws -> MealPhotoEstimate {
        guard let json = fixtures[name] else { throw MealPhotoError.unavailable }
        return try MealPhotoResponseParser.parse(Data(json.utf8))
    }

    static let fixtures: [String: String] = [
        "typical-plate": """
        {"requestId":"mock-typical","model":"gemini-3.5-flash-lite","status":"ok","foods":[
        {"name":"Grilled salmon","grams":120,"lowGrams":100,"highGrams":140,"preparation":"grilled","hiddenFatLikely":true,"volumeMl":null,"match":{"source":"usdaFNDDS","fdcId":175167,"description":"Fish, salmon, Atlantic, farmed, cooked","per100g":{"calories":206,"protein":22.1,"carbs":0,"fat":12.4,"saturatedFat":2.4,"fiber":0,"sugars":0,"sodium":61,"cholesterol":63}}},
        {"name":"Brown rice","grams":180,"lowGrams":150,"highGrams":210,"preparation":"steamed","hiddenFatLikely":false,"volumeMl":null,"match":{"source":"usdaFNDDS","fdcId":169704,"description":"Rice, brown, long-grain, cooked","per100g":{"calories":123,"protein":2.7,"carbs":25.6,"fat":1,"fiber":1.6,"sodium":4}}},
        {"name":"Mixed salad","grams":80,"lowGrams":60,"highGrams":100,"preparation":null,"hiddenFatLikely":true,"volumeMl":null,"match":null}]}
        """,
        "not-food": """
        {"requestId":"mock-not-food","model":"gemini-3.5-flash-lite","status":"not_food","foods":[]}
        """,
        "volume-only-drink": """
        {"requestId":"mock-drink","model":"gemini-3.5-flash-lite","status":"ok","foods":[
        {"name":"Orange juice","grams":null,"lowGrams":null,"highGrams":null,"preparation":null,"hiddenFatLikely":false,"volumeMl":250}]}
        """
    ]
}
#endif
