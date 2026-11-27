import Foundation

enum MealPhotoError: LocalizedError, Equatable {
    case offline, dailyLimit, rateLimited, timeout, unavailable

    var errorDescription: String? {
        switch self {
        case .offline: "You're offline. Check your connection, or search for the foods instead."
        case .dailyLimit: "Meal scanning has reached its limit for today. Try again tomorrow, or search for the foods instead."
        case .rateLimited: "Too many scans right now. Wait a minute and try again."
        case .timeout: "The scan took too long. Try again, or search for the foods instead."
        case .unavailable: "Couldn't scan this photo. Try again, or search for the foods instead."
        }
    }

    var canRetry: Bool { self != .dailyLimit }
}

struct MealPhotoClient {
    static let maximumImageBytes = 1_500_000

    private struct ErrorBody: Decodable { let error: String }

    private let jsonClient: HTTPJSONClient
    private let defaults: UserDefaults

    init(session: URLSession = .shared, defaults: UserDefaults = .standard) {
        jsonClient = HTTPJSONClient(session: session)
        self.defaults = defaults
    }

    func estimate(jpeg: Data) async throws -> MealPhotoEstimate {
        #if DEBUG
        if let fixture = MealPhotoMockFixtures.requestedName { return try MealPhotoMockFixtures.response(named: fixture) }
        #endif
        var request = try jsonClient.makeProxyRequest(
            pathComponents: ["v1", "meal-photo", "estimate"],
            timeoutInterval: 30,
            unavailableConfigurationError: MealPhotoError.unavailable
        )
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue(installID, forHTTPHeaderField: "X-MACROS-Install-ID")
        request.httpBody = jpeg

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await jsonClient.data(for: request)
        } catch let error as URLError {
            throw Self.error(for: error)
        } catch {
            throw MealPhotoError.unavailable
        }
        guard (200...299).contains(response.statusCode) else {
            throw Self.error(forStatus: response.statusCode, body: jsonClient.decodeIfPresent(ErrorBody.self, from: data)?.error)
        }
        do {
            return try MealPhotoResponseParser.parse(data)
        } catch {
            throw MealPhotoError.unavailable
        }
    }

    /// Fire and forget: a lost report costs nothing, so there is no retry.
    func send(_ feedback: MealPhotoFeedback) async {
        #if DEBUG
        if MealPhotoMockFixtures.requestedName != nil { return }
        #endif
        guard
            var request = try? jsonClient.makeProxyRequest(
                pathComponents: ["v1", "meal-photo", "feedback"],
                timeoutInterval: 10,
                unavailableConfigurationError: MealPhotoError.unavailable
            ), let body = try? JSONEncoder().encode(feedback)
        else { return }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        _ = try? await jsonClient.data(for: request)
    }

    /// A random ID created once per install. It is not tied to an account and only enforces the daily cap.
    private var installID: String {
        if let existing = defaults.string(forKey: AppStorageKeys.mealPhotoInstallID) { return existing }
        let created = UUID().uuidString
        defaults.set(created, forKey: AppStorageKeys.mealPhotoInstallID)
        return created
    }

    static func error(for urlError: URLError) -> MealPhotoError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff: .offline
        case .timedOut: .timeout
        default: .unavailable
        }
    }

    static func error(forStatus status: Int, body: String?) -> MealPhotoError {
        switch (status, body) {
        case (429, "daily_limit"): .dailyLimit
        case (429, _): .rateLimited
        case (504, _): .timeout
        default: .unavailable
        }
    }
}
