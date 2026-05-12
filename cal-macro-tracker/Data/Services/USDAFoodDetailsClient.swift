import Foundation

enum USDAFoodDetailsClientError: LocalizedError {
    case unavailableConfiguration
    case invalidFoodID
    case invalidResponse
    case requestFailed(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .unavailableConfiguration:
            return "USDA food details are not configured for this build yet."
        case .invalidFoodID:
            return "The USDA food identifier is invalid."
        case .invalidResponse:
            return "The USDA food details service returned an invalid response."
        case let .requestFailed(_, message):
            return message ?? "The USDA food details service returned an error."
        }
    }
}

private struct USDAFoodDetailsErrorResponse: Decodable {
    let error: String
}

struct USDAFoodDetailsClient {
    private let jsonClient: HTTPJSONClient

    init(session: URLSession = .shared) {
        jsonClient = HTTPJSONClient(session: session)
    }

    func fetchFood(id: Int) async throws -> USDAProxyFood {
        guard id > 0 else {
            throw USDAFoodDetailsClientError.invalidFoodID
        }

        let request = try jsonClient.makeProxyRequest(
            pathComponents: ["v1", "usda", "foods", String(id)],
            unavailableConfigurationError: USDAFoodDetailsClientError.unavailableConfiguration
        )
        return try await jsonClient.proxyResponse(
            for: request,
            responseType: USDAProxyFood.self,
            errorResponseType: USDAFoodDetailsErrorResponse.self,
            invalidResponseError: USDAFoodDetailsClientError.invalidResponse
        ) { statusCode, errorResponse in
            USDAFoodDetailsClientError.requestFailed(
                statusCode: statusCode,
                message: errorResponse?.error
            )
        }
    }
}
