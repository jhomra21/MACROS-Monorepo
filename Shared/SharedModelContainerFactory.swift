import Foundation
import SwiftData

enum SharedModelContainerFactory {
    private static let sharedConfiguration = ModelConfiguration(
        nil,
        schema: nil,
        isStoredInMemoryOnly: false,
        allowsSave: true,
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
        return try ModelContainer(
            for: DailyGoals.self,
            FoodItem.self,
            LogEntry.self,
            configurations: sharedConfiguration
        )
    }

    static func makeReadablePersistentContainerIfAvailable() throws -> ModelContainer? {
        guard FileManager.default.fileExists(atPath: sharedConfiguration.url.path) else {
            return nil
        }

        return try ModelContainer(
            for: DailyGoals.self,
            FoodItem.self,
            LogEntry.self,
            configurations: sharedConfiguration
        )
    }

    private static func migrateLegacyStoreIfNeeded() throws {
        let fileManager = FileManager.default
        let sourceURL = legacyConfiguration.url
        let destinationURL = sharedConfiguration.url

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
}
