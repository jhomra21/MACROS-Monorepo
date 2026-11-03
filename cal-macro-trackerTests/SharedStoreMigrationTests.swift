import Foundation
import SQLite3
import XCTest
@testable import cal_macro_tracker

@MainActor
final class SharedStoreMigrationTests: XCTestCase {
    func testPublishedBaseIsSelfContainedWithoutCopiedSidecars() throws {
        try withStore { source, destination, directory in
            try SharedModelContainerFactory.migrateLegacyStoreIfNeeded(from: source, to: destination)
            let standalone = directory.appendingPathComponent("standalone.sqlite")
            try FileManager.default.copyItem(at: destination, to: standalone)
            XCTAssertEqual(try rows(at: standalone), ["base", "committed WAL"])
        }
    }

    func testRelaunchDiscardsPartialStagingAndPreservesPublishedDestination() throws {
        try withStore { source, destination, _ in
            let staging = URL(fileURLWithPath: destination.path + ".migration")
            try Data("interrupted partial backup".utf8).write(to: staging)
            try SharedModelContainerFactory.migrateLegacyStoreIfNeeded(from: source, to: destination)
            XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path))
            XCTAssertEqual(try rows(at: destination), ["base", "committed WAL"])
            let db = try open(destination, flags: SQLITE_OPEN_READWRITE)
            defer { sqlite3_close(db) }
            try execute("INSERT INTO records VALUES ('post-migration write');", on: db)
            try SharedModelContainerFactory.migrateLegacyStoreIfNeeded(from: source, to: destination)
            XCTAssertEqual(try rows(at: destination), ["base", "committed WAL", "post-migration write"])
        }
    }

    func testCorruptSourceDoesNotPublishAndCanRetry() throws {
        try withStore { source, destination, directory in
            let corrupt = directory.appendingPathComponent("corrupt.sqlite")
            try Data("not sqlite".utf8).write(to: corrupt)
            XCTAssertThrowsError(
                try SharedModelContainerFactory.migrateLegacyStoreIfNeeded(from: corrupt, to: destination)
            )
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
            try SharedModelContainerFactory.migrateLegacyStoreIfNeeded(from: source, to: destination)
            XCTAssertEqual(try rows(at: destination), ["base", "committed WAL"])
        }
    }

    func testPublishFailureLeavesLegacyIntactAndRelaunchRetries() throws {
        try withStore { source, destination, _ in
            XCTAssertThrowsError(
                try SharedModelContainerFactory.migrateLegacyStoreIfNeeded(
                    from: source, to: destination, fileManager: FailedStorePublish()
                )
            )
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
            XCTAssertEqual(try rows(at: source), ["base", "committed WAL"])
            try SharedModelContainerFactory.migrateLegacyStoreIfNeeded(from: source, to: destination)
            XCTAssertEqual(try rows(at: destination), ["base", "committed WAL"])
        }
    }

    func testMissingSourceAndSamePathAreNoOps() throws {
        try withStore { source, destination, directory in
            try SharedModelContainerFactory.migrateLegacyStoreIfNeeded(
                from: directory.appendingPathComponent("missing.sqlite"), to: destination
            )
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
            try SharedModelContainerFactory.migrateLegacyStoreIfNeeded(from: source, to: source)
            XCTAssertEqual(try rows(at: source), ["base", "committed WAL"])
        }
    }

    private func withStore(_ body: (URL, URL, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("StoreMigration-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("legacy.sqlite")
        let destination = directory.appendingPathComponent("shared.sqlite")
        let db = try open(source, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        defer { sqlite3_close(db) }
        try execute("PRAGMA journal_mode=WAL; PRAGMA wal_autocheckpoint=0;", on: db)
        try execute("CREATE TABLE records(value TEXT); INSERT INTO records VALUES ('base');", on: db)
        try execute("PRAGMA wal_checkpoint(TRUNCATE);", on: db)
        try execute("INSERT INTO records VALUES ('committed WAL');", on: db)
        XCTAssertGreaterThan(
            (try FileManager.default.attributesOfItem(atPath: source.path + "-wal")[.size] as? NSNumber)?.intValue ?? 0, 0
        )
        let legacyBase = try Data(contentsOf: source)
        let legacyWAL = try Data(contentsOf: URL(fileURLWithPath: source.path + "-wal"))
        try body(source, destination, directory)
        XCTAssertEqual(try Data(contentsOf: source), legacyBase)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: source.path + "-wal")), legacyWAL)
    }

    private func rows(at url: URL) throws -> [String] {
        let db = try open(url, flags: SQLITE_OPEN_READWRITE)
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT value FROM records ORDER BY rowid", -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteFailure.failed
        }
        defer { sqlite3_finalize(statement) }
        var values: [String] = []
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            values.append(String(cString: sqlite3_column_text(statement, 0)))
            result = sqlite3_step(statement)
        }
        XCTAssertEqual(result, SQLITE_DONE)
        return values
    }

    private func open(_ url: URL, flags: Int32) throws -> OpaquePointer {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK, let db else {
            sqlite3_close(db)
            throw SQLiteFailure.failed
        }
        return db
    }

    private func execute(_ sql: String, on db: OpaquePointer) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw SQLiteFailure.failed }
    }

    private enum SQLiteFailure: Error { case failed }
}

private final class FailedStorePublish: FileManager, @unchecked Sendable {
    override func moveItem(at source: URL, to destination: URL) throws {
        throw CocoaError(.fileWriteOutOfSpace)
    }
}
