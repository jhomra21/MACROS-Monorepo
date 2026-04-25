import Foundation
import SwiftData

enum SharedModelContainerFactory {
    private static let sharedWritableConfiguration = ModelConfiguration(
        nil,
        schema: nil,
        isStoredInMemoryOnly: false,
        allowsSave: true,
        groupContainer: .identifier(SharedAppConfiguration.appGroupIdentifier),
        cloudKitDatabase: .none
    )

    private static let sharedReadOnlyConfiguration = ModelConfiguration(
        nil,
        schema: nil,
        isStoredInMemoryOnly: false,
        allowsSave: false,
        groupContainer: .identifier(SharedAppConfiguration.appGroupIdentifier),
        cloudKitDatabase: .none
    )

    private static let legacyConfiguration = ModelConfiguration(
        nil,
        schema: nil,
        isStoredInMemoryOnly: false,
        allowsSave: true,
        groupContainer: .none,
        cloudKitDatabase: .none
    )

    static func makePersistentContainer() throws -> ModelContainer {
        try migrateLegacyStoreIfNeeded()
        let container = try ModelContainer(
            for: DailyGoals.self,
            FoodItem.self,
            LogEntry.self,
            configurations: sharedWritableConfiguration
        )
        try applySharedStoreFileProtectionIfNeeded()
        return container
    }

    static func makeReadablePersistentContainerIfAvailable() throws -> ModelContainer? {
        guard FileManager.default.fileExists(atPath: sharedWritableConfiguration.url.path) else {
            return nil
        }

        return try ModelContainer(
            for: DailyGoals.self,
            FoodItem.self,
            LogEntry.self,
            configurations: sharedReadOnlyConfiguration
        )
    }

    private static func migrateLegacyStoreIfNeeded() throws {
        let fileManager = FileManager.default
        let sourceURL = legacyConfiguration.url
        let destinationURL = sharedWritableConfiguration.url

        guard
            sourceURL != destinationURL,
            !fileManager.fileExists(atPath: destinationURL.path),
            fileManager.fileExists(atPath: sourceURL.path)
        else {
            return
        }

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        for sourceArtifactURL in storeArtifactURLs(for: sourceURL) {
            guard fileManager.fileExists(atPath: sourceArtifactURL.path) else { continue }

            let destinationArtifactURL = pairedArtifactURL(sourceArtifactURL, from: sourceURL, to: destinationURL)
            guard !fileManager.fileExists(atPath: destinationArtifactURL.path) else { continue }

            try fileManager.copyItem(at: sourceArtifactURL, to: destinationArtifactURL)
        }
    }

    private static func storeArtifactURLs(for baseURL: URL) -> [URL] {
        let sidecarURLs = ["-shm", "-wal"].map { suffix in
            URL(fileURLWithPath: baseURL.path + suffix)
        }

        return [baseURL] + sidecarURLs
    }

    private static func pairedArtifactURL(
        _ artifactURL: URL,
        from sourceBaseURL: URL,
        to destinationBaseURL: URL
    ) -> URL {
        let suffix = String(artifactURL.path.dropFirst(sourceBaseURL.path.count))
        return URL(fileURLWithPath: destinationBaseURL.path + suffix)
    }

    #if os(iOS)
    private static func applySharedStoreFileProtectionIfNeeded() throws {
        let fileManager = FileManager.default
        let attributes: [FileAttributeKey: Any] = [
            .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
        ]

        for artifactURL in storeArtifactURLs(for: sharedWritableConfiguration.url) where fileManager.fileExists(atPath: artifactURL.path) {
            try fileManager.setAttributes(attributes, ofItemAtPath: artifactURL.path)
        }
    }
    #else
    private static func applySharedStoreFileProtectionIfNeeded() throws {}
    #endif
}
