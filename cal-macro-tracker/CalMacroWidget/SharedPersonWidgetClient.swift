#if os(iOS)
import Foundation

nonisolated enum SharedWidgetFetchError: Error {
    case transient(retryAfter: Date? = nil)
    case unavailable
    case reconnect
    case tokenRejected
}

nonisolated private struct SharedWidgetTokenRequest: Encodable, Sendable {
    let profileKey: String
    let profileSecret: String
}

nonisolated private struct SharedWidgetTokenResponse: Decodable, Sendable {
    nonisolated struct Profile: Decodable, Sendable {
        let profileKey: String
        let deleted: Bool
    }
    let token: String
    let expiresAt: Double
    let profile: Profile
}

nonisolated private struct SharedWidgetQuery: Encodable, Sendable {
    nonisolated struct Arguments: Encodable, Sendable {
        let otherProfileId: String
        let day: String
        let ownerToday: String
        let includeFoods = false
    }
    let path = "sharing:personDay"
    let format = "json"
    let args: Arguments
}

nonisolated private struct SharedWidgetQueryEnvelope: Decodable, Sendable {
    let status: String
    let value: SharedWidgetPersonDay?
}

actor SharedPersonWidgetClient {
    static let shared = SharedPersonWidgetClient()
    private static let retryAfterFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return formatter
    }()
    private let session: URLSession
    // No access group: this JWT is private to the extension, never published by the app.
    private let tokenItem = SharingKeychainItem(
        service: "juan-test.cal-macro-tracker.shared-widget", account: "widget-session"
    )
    private var exchange: (profileKey: String, generation: UUID, task: Task<SharedWidgetTokenCache, Error>)?

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 10
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
    }

    func clearToken() {
        try? tokenItem.delete()
    }

    func personDay(profileId: String, day: String, generation: UUID) async throws -> SharedWidgetPersonDay {
        guard let data = try SharingKeychainItem.identity.load() else { throw SharedWidgetFetchError.reconnect }
        guard let identity = try? JSONDecoder().decode(SharingIdentity.self, from: data) else {
            throw SharedWidgetFetchError.reconnect
        }
        let token = try await accessToken(identity: identity, generation: generation)
        do {
            return try await query(token: token, profileId: profileId, day: day)
        } catch SharedWidgetFetchError.unavailable, SharedWidgetFetchError.tokenRejected {
            clearToken()
            let refreshed = try await accessToken(identity: identity, generation: generation)
            // Only a second decoded error envelope is authoritative. Transport errors
            // during refresh/retry remain transient and preserve eligible last-good.
            return try await query(token: refreshed, profileId: profileId, day: day)
        }
    }

    private func accessToken(identity: SharingIdentity, generation: UUID) async throws -> String {
        if let data = try tokenItem.load(),
            let cached = try? JSONDecoder().decode(SharedWidgetTokenCache.self, from: data),
            cached.isUsable(profileKey: identity.profileKey, generation: generation)
        {
            return cached.token
        }
        clearToken()
        let task: Task<SharedWidgetTokenCache, Error>
        if let exchange, exchange.profileKey == identity.profileKey, exchange.generation == generation {
            task = exchange.task
        } else {
            let session = session
            task = Task {
                var request = URLRequest(url: SharedAppConfiguration.authBaseURL.appending(path: "v1/token"))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(
                    SharedWidgetTokenRequest(profileKey: identity.profileKey, profileSecret: identity.profileSecret)
                )
                let (data, response) = try await Self.send(request, session: session)
                guard (200...299).contains(response.statusCode),
                    let result = try? JSONDecoder().decode(SharedWidgetTokenResponse.self, from: data),
                    !result.profile.deleted, result.profile.profileKey == identity.profileKey,
                    !result.token.isEmpty, result.expiresAt.isFinite,
                    result.expiresAt > Date.now.addingTimeInterval(300).timeIntervalSince1970 * 1000
                else { throw SharedWidgetFetchError.transient() }
                return SharedWidgetTokenCache(
                    token: result.token, expiresAt: result.expiresAt,
                    profileKey: identity.profileKey, deploymentURL: SharedAppConfiguration.convexDeploymentURL,
                    generation: generation
                )
            }
            exchange = (identity.profileKey, generation, task)
        }
        defer { exchange = nil }
        let cached = try await task.value
        try tokenItem.save(JSONEncoder().encode(cached))
        return cached.token
    }

    private func query(token: String, profileId: String, day: String) async throws -> SharedWidgetPersonDay {
        var request = URLRequest(url: URL(string: SharedAppConfiguration.convexDeploymentURL)!.appending(path: "api/query"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            SharedWidgetQuery(args: .init(otherProfileId: profileId, day: day, ownerToday: day))
        )
        let (data, response) = try await Self.send(request, session: session)
        if response.statusCode == 401 { throw SharedWidgetFetchError.tokenRejected }
        guard let envelope = try? JSONDecoder().decode(SharedWidgetQueryEnvelope.self, from: data) else {
            throw SharedWidgetFetchError.transient()
        }
        if envelope.status == "error" { throw SharedWidgetFetchError.unavailable }
        guard (200...299).contains(response.statusCode), envelope.status == "success",
            let value = envelope.value,
            value.snapshot.map({ $0.isValid && $0.day == day }) ?? true
        else { throw SharedWidgetFetchError.transient() }
        return value
    }

    private static func send(_ request: URLRequest, session: URLSession) async throws -> (Data, HTTPURLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw SharedWidgetFetchError.transient() }
        guard response.expectedContentLength <= 32768 else { throw SharedWidgetFetchError.transient() }
        if response.statusCode == 429 || response.statusCode >= 500 {
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap { value -> Date? in
                if let seconds = Double(value), seconds.isFinite, seconds >= 0 {
                    return min(.now.addingTimeInterval(seconds), SharedPersonWidgetClock.nextMidnight(after: .now))
                }
                return retryAfterFormatter.date(from: value).map {
                    min($0, SharedPersonWidgetClock.nextMidnight(after: .now))
                }
            }
            throw SharedWidgetFetchError.transient(retryAfter: retryAfter)
        }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 32768 else { throw SharedWidgetFetchError.transient() }
            data.append(byte)
        }
        return (data, response)
    }
}
#endif
