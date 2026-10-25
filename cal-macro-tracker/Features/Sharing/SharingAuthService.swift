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
    private var identityGeneration = UUID()

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
        invalidateIdentity()
    }

    func extractIdToken(from authResult: SharingAuthSession) -> String {
        authResult.token
    }

    private func tokenExchange(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> SharingAuthSession {
        let generation = identityGeneration
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
                requestFailedError: { _, _, _ in HTTPJSONClientError.invalidResponse }
            )
            guard identityGeneration == generation else { throw CancellationError() }
            onIdToken(authSession.token)
            return authSession
        } catch {
            if identityGeneration == generation { onIdToken(nil) }
            throw error
        }
    }

    func invalidateIdentity() {
        identityGeneration = UUID()
    }
}

@MainActor
@Observable
final class SharingAuthService: SharingCredentialCleanup {
    private let authProvider: SharingAuthProvider
    private let identityStore: SharingIdentityStore
    let client: ConvexClientWithAuth<SharingAuthSession>
    private(set) var session: SharingAuthSession?
    private var identityGeneration = UUID()
    private var authenticationTask: Task<SharingAuthSession, Error>?

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
        if let authenticationTask { return try await authenticationTask.value }
        let generation = identityGeneration
        authProvider.setDisplayName(displayName)
        let task = Task { @MainActor in
            defer { self.authenticationTask = nil }
            switch await self.client.loginFromCache() {
            case let .success(session):
                guard self.identityGeneration == generation else { throw CancellationError() }
                self.session = session
                return session
            case let .failure(error):
                throw error
            }
        }
        authenticationTask = task
        return try await task.value
    }

    func clearLocalIdentity() async throws {
        identityGeneration = UUID()
        authProvider.invalidateIdentity()
        session = nil
        // Let any in-flight login settle before final logout. The SDK installs its
        // auth bridge after the provider returns, so cancellation alone is insufficient.
        if let authenticationTask { _ = try? await authenticationTask.value }
        await client.logout()
        try identityStore.delete()
    }
}
