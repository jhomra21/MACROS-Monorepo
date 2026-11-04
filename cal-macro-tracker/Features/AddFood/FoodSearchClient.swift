import Foundation

struct FoodSearchPage: Decodable {
    let query: String
    let results: [RemoteSearchResult]
    let nextCursor: String?
}

private struct FoodSearchErrorResponse: Decodable {}

enum FoodSearchClientError: LocalizedError {
    case unavailable

    var errorDescription: String? { "Try again" }
}

struct FoodSearchClient {
    static let minimumQueryLength = 3

    private let jsonClient: HTTPJSONClient

    init(session: URLSession = .shared) {
        jsonClient = HTTPJSONClient(session: session)
    }

    func searchFoods(query: String, cursor: String? = nil) async throws -> FoodSearchPage {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedQuery.count >= Self.minimumQueryLength else {
            throw FoodSearchClientError.unavailable
        }
        let request = try jsonClient.makeProxyRequest(
            pathComponents: ["v2", "foods", "search"],
            queryItems: [
                URLQueryItem(name: "q", value: normalizedQuery),
                cursor.map { URLQueryItem(name: "cursor", value: $0) }
            ],
            unavailableConfigurationError: FoodSearchClientError.unavailable
        )
        return try await jsonClient.proxyResponse(
            for: request,
            responseType: FoodSearchPage.self,
            errorResponseType: FoodSearchErrorResponse.self,
            invalidResponseError: FoodSearchClientError.unavailable
        ) { _, _, _ in
            FoodSearchClientError.unavailable
        }
    }
}
