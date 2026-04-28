import Foundation

enum RemoteFoodSearchConfiguration {
    private static let infoDictionaryBaseURLKey = "USDA_PROXY_BASE_URL"
    private static let debugOverrideEnvironmentKey = "PACKAGED_FOOD_SEARCH_BASE_URL_OVERRIDE"

    static var isPackagedFoodSearchAvailable: Bool {
        packagedFoodSearchBaseURL != nil
    }

    static var packagedFoodSearchBaseURL: URL? {
        debugOverrideBaseURL ?? configuredBaseURL
    }

    private static var configuredBaseURL: URL? {
        baseURL(from: Bundle.main.object(forInfoDictionaryKey: infoDictionaryBaseURLKey) as? String)
    }

    #if DEBUG
    private static var debugOverrideBaseURL: URL? {
        baseURL(from: ProcessInfo.processInfo.environment[debugOverrideEnvironmentKey])
    }
    #else
    private static let debugOverrideBaseURL: URL? = nil
    #endif

    private static func baseURL(from rawValue: String?) -> URL? {
        guard let rawValue else { return nil }
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else { return nil }
        return URL(string: trimmedValue)
    }
}
