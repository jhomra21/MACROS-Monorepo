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
        {"name":"Grilled salmon","grams":120,"lowGrams":100,"highGrams":140,"preparation":"grilled","hiddenFatLikely":true,"volumeMl":null},
        {"name":"Brown rice","grams":180,"lowGrams":150,"highGrams":210,"preparation":"steamed","hiddenFatLikely":false,"volumeMl":null},
        {"name":"Mixed salad","grams":80,"lowGrams":60,"highGrams":100,"preparation":null,"hiddenFatLikely":true,"volumeMl":null}]}
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
