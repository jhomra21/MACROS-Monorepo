import Foundation

enum SupportCategory: String, CaseIterable, Codable, Identifiable {
    case bug = "Bug"
    case featureRequest = "Feature request"
    case question = "Question"
    case other = "Other"

    var id: Self { self }
}

struct SupportRequest: Encodable {
    let category: SupportCategory
    let message: String
    let email: String?
    let appVersion: String
    let build: String
    let osVersion: String
    let deviceModel: String

    static func make(
        category: SupportCategory,
        message: String,
        email: String,
        appVersion: String,
        build: String,
        osVersion: String,
        deviceModel: String
    ) -> Self {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self(
            category: category,
            message: message,
            email: trimmedEmail.isEmpty ? nil : trimmedEmail,
            appVersion: appVersion,
            build: build,
            osVersion: osVersion,
            deviceModel: deviceModel
        )
    }

    var isValid: Bool {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (10...4_000).contains(trimmedMessage.count) else { return false }
        guard let email else { return true }
        return Self.isValidEmail(email)
    }

    private static func isValidEmail(_ email: String) -> Bool {
        guard email.count <= 254 else { return false }
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2
            && !parts[0].isEmpty
            && parts[0].count <= 64
            && parts[1].contains(".")
            && !parts[1].hasPrefix(".")
            && !parts[1].hasSuffix(".")
            && !email.contains(where: \.isWhitespace)
    }
}

enum SupportRequestClient {
    nonisolated static let endpoint = URL(string: "https://support.macrosios.com/v1/requests")!

    static func makeRequest(for supportRequest: SupportRequest, endpoint: URL = endpoint) throws -> URLRequest {
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(supportRequest)
        return request
    }

    static func send(_ supportRequest: SupportRequest, endpoint: URL = endpoint) async throws {
        let (data, response) = try await URLSession.shared.data(for: makeRequest(for: supportRequest, endpoint: endpoint))
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? ""])
        }
    }
}
