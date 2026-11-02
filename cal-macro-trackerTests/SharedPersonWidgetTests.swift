import Foundation
import Security
import XCTest
@testable import cal_macro_tracker

final class SharedPersonWidgetTests: XCTestCase {
    // Failure inventory (preimplementation): calendar midnight must not use 86400
    // across DST; refresh must not cross midnight; identity migration must preserve
    // bytes, verify before deleting, be idempotent, and leave legacy operations
    // unscoped. Fresh identities use the group; invite-like items stay private.
    func testCalendarMidnightAndRefreshAcrossDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let formatter = ISO8601DateFormatter()
        for (start, end, hours) in [
            ("2026-03-08T08:00:00Z", "2026-03-09T07:00:00Z", 23.0),
            ("2026-11-01T07:00:00Z", "2026-11-02T08:00:00Z", 25.0)
        ] {
            let date = try XCTUnwrap(formatter.date(from: start))
            let midnight = try XCTUnwrap(formatter.date(from: end))
            XCTAssertEqual(SharedPersonWidgetClock.nextMidnight(after: date, calendar: calendar), midnight)
            XCTAssertEqual(midnight.timeIntervalSince(date), hours * 3600)
            XCTAssertEqual(SharedPersonWidgetClock.refreshDate(after: date, calendar: calendar), date.addingTimeInterval(1800))
            let late = midnight.addingTimeInterval(-600)
            XCTAssertEqual(SharedPersonWidgetClock.refreshDate(after: late, calendar: calendar), midnight)
        }
        XCTAssertEqual(
            SharedPersonWidgetClock.dayKey(for: try XCTUnwrap(formatter.date(from: "2026-11-02T07:59:00Z")), calendar: calendar),
            "2026-11-01"
        )
    }

    func testIdentityMigrationPreservesBytesAndLegacyOperations() throws {
        let service = "SharedPersonWidgetTests.\(UUID().uuidString)"
        let legacy = SharingKeychainItem(service: service, account: "identity")
        let shared = SharingKeychainItem(
            service: service, account: "identity", accessGroup: SharedAppConfiguration.appGroupIdentifier
        )
        defer { try? legacy.delete() }
        let original = Data("synthetic-identity".utf8)
        try legacy.save(original)
        XCTAssertNotEqual(try group(service: service), SharedAppConfiguration.appGroupIdentifier)
        try shared.migrateToAccessGroup()
        XCTAssertEqual(try group(service: service), SharedAppConfiguration.appGroupIdentifier)
        XCTAssertEqual(try legacy.load(), original)
        try shared.migrateToAccessGroup()
        XCTAssertEqual(try shared.load(), original)
        let updated = Data("synthetic-updated".utf8)
        try legacy.save(updated)
        XCTAssertEqual(try shared.load(), updated)
        try legacy.delete()
        XCTAssertNil(try shared.load())
    }

    func testFreshIdentityIsSharedAndInviteIsPrivate() throws {
        let service = "SharedPersonWidgetTests.\(UUID().uuidString)"
        let shared = SharingKeychainItem(
            service: service, account: "identity", accessGroup: SharedAppConfiguration.appGroupIdentifier
        )
        let invite = SharingKeychainItem(service: service, account: "invite")
        defer { try? shared.delete(); try? invite.delete() }
        try shared.migrateToAccessGroup()
        XCTAssertNil(try shared.load())
        try shared.save(Data("synthetic".utf8))
        try invite.save(Data("synthetic-invite".utf8))
        XCTAssertEqual(try group(service: service), SharedAppConfiguration.appGroupIdentifier)
        XCTAssertNotEqual(try group(service: service, account: "invite"), SharedAppConfiguration.appGroupIdentifier)
    }

    private func group(service: String, account: String = "identity") throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &result), errSecSuccess)
        return try XCTUnwrap((result as? [String: Any])?[kSecAttrAccessGroup as String] as? String)
    }
}
