import Foundation

struct PackagedFoodSearchPage {
    let query: String
    let page: Int
    let provider: RemoteSearchProvider
    let results: [RemoteSearchResult]
    let hasMore: Bool
}

private struct PackagedFoodSearchResponse: Decodable {
    let query: String
    let page: Int
    let resolvedProvider: RemoteSearchProvider?
    let results: [PackagedFoodSearchResultDTO]
    let hasMore: Bool

    func pageResults(requestedProvider: RemoteSearchProvider?) -> PackagedFoodSearchPage {
        let provider = resolvedProvider ?? results.first?.provider ?? requestedProvider ?? .openFoodFacts

        return PackagedFoodSearchPage(
            query: query,
            page: page,
            provider: provider,
            results: results.map(\.remoteSearchResult),
            hasMore: hasMore
        )
    }
}

private struct PackagedFoodSearchResultDTO: Decodable {
    let provider: RemoteSearchProvider
    let remoteSearchResult: RemoteSearchResult

    private enum CodingKeys: String, CodingKey {
        case provider
        case item
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decode(RemoteSearchProvider.self, forKey: .provider)
        switch provider {
        case .openFoodFacts:
            let product = try container.decode(OpenFoodFactsProduct.self, forKey: .item)
            remoteSearchResult = .openFoodFacts(product)
        case .usda:
            let food = try container.decode(USDAProxyFood.self, forKey: .item)
            remoteSearchResult = .usda(food)
        }
    }
}

private struct PackagedFoodSearchErrorResponse: Decodable {
    let error: String
}

enum PackagedFoodSearchClientError: LocalizedError {
    case unavailableConfiguration
    case invalidQuery
    case invalidResponse
    case requestFailed(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .unavailableConfiguration:
            return "Online packaged food search is not configured for this build yet."
        case .invalidQuery:
            return "Enter at least 2 characters to search online."
        case .invalidResponse:
            return "The packaged food search service returned an invalid response."
        case let .requestFailed(_, message):
            return message ?? "The packaged food search service returned an error."
        }
    }
}

struct PackagedFoodSearchClient {
    static let minimumQueryLength = 2

    private let jsonClient: HTTPJSONClient

    init(session: URLSession = .shared) {
        jsonClient = HTTPJSONClient(session: session)
    }

    func searchFoods(
        query: String,
        page: Int,
        pageSize: Int,
        fallbackOnEmpty: Bool = true,
        provider: RemoteSearchProvider? = nil
    ) async throws -> PackagedFoodSearchPage {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedQuery.count >= Self.minimumQueryLength else {
            throw PackagedFoodSearchClientError.invalidQuery
        }

        guard let baseURL = RemoteFoodSearchConfiguration.packagedFoodSearchBaseURL else {
            throw PackagedFoodSearchClientError.unavailableConfiguration
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("v1/packaged-foods/search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: normalizedQuery),
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "pageSize", value: String(max(1, pageSize))),
            URLQueryItem(name: "fallbackOnEmpty", value: fallbackOnEmpty ? "1" : "0"),
            provider.map { URLQueryItem(name: "provider", value: $0.rawValue) }
        ].compactMap { $0 }

        guard let url = components?.url else {
            throw PackagedFoodSearchClientError.invalidResponse
        }

        let request = jsonClient.makeRequest(url: url, acceptJSON: true)
        let data: Data
        let httpResponse: HTTPURLResponse

        do {
            (data, httpResponse) = try await jsonClient.data(for: request)
        } catch HTTPJSONClientError.invalidResponse {
            throw PackagedFoodSearchClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorResponse = jsonClient.decodeIfPresent(PackagedFoodSearchErrorResponse.self, from: data)
            throw PackagedFoodSearchClientError.requestFailed(statusCode: httpResponse.statusCode, message: errorResponse?.error)
        }

        let decodedResponse = try jsonClient.decode(PackagedFoodSearchResponse.self, from: data)
        return decodedResponse.pageResults(requestedProvider: provider)
    }
}
