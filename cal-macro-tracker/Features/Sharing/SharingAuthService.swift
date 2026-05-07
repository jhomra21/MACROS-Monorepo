import ConvexMobile
import Foundation

struct SharingAuthSession: Decodable {
    let token: String
    let expiresAt: Int
    let profile: SharingProfile
}

struct SharingProfile: Decodable, Hashable {
    let profileKey: String
    let displayName: String
    let deleted: Bool
}

private struct SharingTokenRequest: Encodable {
    let profileKey: String
    let profileSecret: String
    let displayName: String
}

private struct SharingTokenErrorResponse: Decodable {}

private final class SharingAuthProvider: AuthProvider {
    typealias T = SharingAuthSession

    private let identityStore: SharingIdentityStore
    private let authBaseURL: URL
    private let jsonClient: HTTPJSONClient
    private var displayName = "Me"

    init(
        identityStore: SharingIdentityStore,
        authBaseURL: URL,
        session: URLSession = .shared
    ) {
        self.identityStore = identityStore
        self.authBaseURL = authBaseURL
        jsonClient = HTTPJSONClient(session: session)
    }

    func setDisplayName(_ displayName: String) {
        self.displayName = displayName
    }

    func login(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> SharingAuthSession {
        try await tokenExchange(onIdToken: onIdToken)
    }

    func loginFromCache(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> SharingAuthSession {
        try await tokenExchange(onIdToken: onIdToken)
    }

    func logout() async throws {
        onLogout()
    }

    func extractIdToken(from authResult: SharingAuthSession) -> String {
        authResult.token
    }

    private func tokenExchange(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> SharingAuthSession {
        // Sharing identity is intentionally device-local and non-recoverable if Keychain data is lost.
        let identity = try identityStore.loadOrCreate()
        let url = authBaseURL.appending(path: "v1/token")
        var request = jsonClient.makeRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            SharingTokenRequest(
                profileKey: identity.profileKey,
                profileSecret: identity.profileSecret,
                displayName: displayName
            )
        )

        do {
            let authSession = try await jsonClient.proxyResponse(
                for: request,
                responseType: SharingAuthSession.self,
                errorResponseType: SharingTokenErrorResponse.self,
                invalidResponseError: HTTPJSONClientError.invalidResponse,
                requestFailedError: { _, _ in HTTPJSONClientError.invalidResponse }
            )
            onIdToken(authSession.token)
            return authSession
        } catch {
            onIdToken(nil)
            throw error
        }
    }

    private func onLogout() {
    }
}

@MainActor
@Observable
final class SharingAuthService {
    private let authProvider: SharingAuthProvider
    private let identityStore: SharingIdentityStore
    let client: ConvexClientWithAuth<SharingAuthSession>
    private(set) var session: SharingAuthSession?

    init(
        configuration: SharingConfiguration.Type = SharingConfiguration.self,
        identityStore: SharingIdentityStore? = nil
    ) {
        let identityStore = identityStore ?? SharingIdentityStore()
        let authProvider = SharingAuthProvider(
            identityStore: identityStore,
            authBaseURL: configuration.authBaseURL
        )
        self.authProvider = authProvider
        self.identityStore = identityStore
        self.client = ConvexClientWithAuth(
            deploymentUrl: configuration.convexDeploymentURL,
            authProvider: authProvider
        )
    }

    @discardableResult
    func authenticate(displayName: String = "Me") async throws -> SharingAuthSession {
        authProvider.setDisplayName(displayName)
        switch await client.loginFromCache() {
        case let .success(session):
            self.session = session
            return session
        case let .failure(error):
            throw error
        }
    }

    func clearLocalIdentity() async throws {
        await client.logout()
        try identityStore.delete()
        session = nil
    }
}
