import Darwin
import Foundation
import SQLite3
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
            BodyProfile.self,
            FoodItem.self,
            Meal.self,
            MealComponent.self,
            LoggedMealComponentSnapshot.self,
            LogEntry.self,
            WeightEntry.self,
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
            BodyProfile.self,
            FoodItem.self,
            Meal.self,
            MealComponent.self,
            LoggedMealComponentSnapshot.self,
            LogEntry.self,
            WeightEntry.self,
            configurations: sharedReadOnlyConfiguration
        )
    }

    private static func migrateLegacyStoreIfNeeded() throws {
        try migrateLegacyStoreIfNeeded(from: legacyConfiguration.url, to: sharedWritableConfiguration.url)
    }

    static func migrateLegacyStoreIfNeeded(
        from sourceURL: URL,
        to destinationURL: URL,
        fileManager: FileManager = .default
    ) throws {
        guard sourceURL != destinationURL else { return }
        guard
            !fileManager.fileExists(atPath: destinationURL.path),
            fileManager.fileExists(atPath: sourceURL.path)
        else {
            return
        }

        let stagingURL = URL(fileURLWithPath: destinationURL.path + ".migration")
        let stagingArtifacts = storeArtifactURLs(for: stagingURL) + [URL(fileURLWithPath: stagingURL.path + "-journal")]
        for artifact in stagingArtifacts where fileManager.fileExists(atPath: artifact.path) {
            try fileManager.removeItem(at: artifact)
        }

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        defer {
            for artifact in stagingArtifacts where fileManager.fileExists(atPath: artifact.path) {
                try? fileManager.removeItem(at: artifact)
            }
        }
        // absent → staging → self-contained base → published.
        // The widget only opens destinationURL, never the staging path.
        try backupLegacyStore(from: sourceURL, to: stagingURL)
        try applySharedStoreFileProtectionIfNeeded(at: stagingURL)
        let file = try FileHandle(forWritingTo: stagingURL)
        defer { try? file.close() }
        // Unlike fsync, F_FULLFSYNC also asks the drive to flush its cache.
        guard fcntl(file.fileDescriptor, F_FULLFSYNC) != -1 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        // Same directory/volume: move is a rename, not a multi-artifact copy.
        try fileManager.moveItem(at: stagingURL, to: destinationURL)
        let directory = open(destinationURL.deletingLastPathComponent().path, O_RDONLY)
        if directory >= 0 {
            defer { close(directory) }
            // Directory full-sync is best effort; publication has already succeeded.
            _ = fcntl(directory, F_FULLFSYNC)
        }
    }

    private static func backupLegacyStore(from sourceURL: URL, to stagingURL: URL) throws {
        var source: OpaquePointer?
        defer { sqlite3_close(source) }
        try checkSQLite(sqlite3_open_v2(sourceURL.path, &source, SQLITE_OPEN_READONLY, nil))
        var destination: OpaquePointer?
        defer { sqlite3_close(destination) }
        try checkSQLite(sqlite3_open_v2(stagingURL.path, &destination, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil))

        // SQLite reads committed WAL frames under its own read lock; raw file
        // copies (and VACUUM's potentially changed row IDs) are not equivalent.
        guard let backup = sqlite3_backup_init(destination, "main", source, "main") else {
            throw sqliteFailure(sqlite3_errcode(destination))
        }
        let step = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        guard step == SQLITE_DONE else {
            throw sqliteFailure(step)
        }
        try checkSQLite(finish)
        guard try sqliteText("PRAGMA journal_mode=DELETE", in: destination) == "delete" else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    private static func checkSQLite(_ result: Int32) throws {
        guard result == SQLITE_OK else { throw sqliteFailure(result) }
    }

    private static func sqliteFailure(_ result: Int32) -> NSError {
        NSError(
            domain: "SharedStoreMigration.SQLite", code: Int(result),
            userInfo: [NSLocalizedDescriptionKey: "The legacy database could not be safely copied."]
        )
    }

    private static func sqliteText(_ sql: String, in database: OpaquePointer?) throws -> String {
        var statement: OpaquePointer?
        try checkSQLite(sqlite3_prepare_v2(database, sql, -1, &statement, nil))
        defer { sqlite3_finalize(statement) }
        let result = sqlite3_step(statement)
        guard result == SQLITE_ROW else { throw sqliteFailure(result) }
        return String(cString: sqlite3_column_text(statement, 0))
    }

    private static func storeArtifactURLs(for baseURL: URL) -> [URL] {
        [baseURL] + ["-shm", "-wal"].map { URL(fileURLWithPath: baseURL.path + $0) }
    }

    #if os(iOS)
    private static func applySharedStoreFileProtectionIfNeeded(at baseURL: URL = sharedWritableConfiguration.url) throws {
        let fileManager = FileManager.default
        let attributes: [FileAttributeKey: Any] = [
            .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
        ]

        for artifactURL in storeArtifactURLs(for: baseURL) where fileManager.fileExists(atPath: artifactURL.path) {
            try fileManager.setAttributes(attributes, ofItemAtPath: artifactURL.path)
        }
    }
    #else
    private static func applySharedStoreFileProtectionIfNeeded(at baseURL: URL = sharedWritableConfiguration.url) throws {}
    #endif
}
