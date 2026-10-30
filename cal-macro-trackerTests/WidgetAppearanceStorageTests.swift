import Foundation
import XCTest
@testable import cal_macro_tracker

final class WidgetAppearanceStorageTests: XCTestCase {
    // Failure inventory: invalid color/version data must not reach rendering;
    // missing data starts native with unknown access; photo IDs are opaque UUIDs;
    // Pro projection comes only from a committed entitlement resolution.
    func testColorSelectionAcceptsOnlySixDigitSRGBHex() throws {
        XCTAssertEqual(WidgetBackgroundSelection.validatedColor("#2466E6"), .color(hex: "#2466E6"))
        XCTAssertNil(WidgetBackgroundSelection.validatedColor("2466E6"))
        XCTAssertNil(WidgetBackgroundSelection.validatedColor("#12GG56"))
        XCTAssertNil(WidgetBackgroundSelection.validatedColor("#2466E6FF"))
    }

    func testVersionedRecordRoundTripsValidatedSelectionAndAccess() throws {
        let record = WidgetAppearanceRecord(
            background: .color(hex: "#2466E6")
        )

        let data = try JSONEncoder().encode(record)
        XCTAssertEqual(WidgetAppearanceStorage.decodeRecord(data), record)
        let accessData = try JSONEncoder().encode(WidgetProAccessRecord(access: .allowed))
        XCTAssertEqual(try JSONDecoder().decode(WidgetProAccessRecord.self, from: accessData).access, .allowed)
    }

    func testMissingOrUnsupportedRecordFailsClosed() throws {
        XCTAssertNil(WidgetAppearanceStorage.decodeRecord(nil))
        let unsupported = Data(##"{"version":99,"background":{"native":{}}}"##.utf8)
        XCTAssertNil(WidgetAppearanceStorage.decodeRecord(unsupported))
    }

    func testInvalidPersistedColorAndUnknownAccessDoNotUnlock() throws {
        let invalid = Data(
            ##"{"version":1,"background":{"color":{"hex":"#12GG56"}}}"##.utf8
        )
        XCTAssertNil(WidgetAppearanceStorage.decodeRecord(invalid))
        XCTAssertEqual(WidgetProAccess.projected(hasPro: false), .denied)
    }

    func testPhotoSelectionUsesOnlyGeneratedUUIDIdentity() {
        let identifier = UUID()
        XCTAssertEqual(WidgetBackgroundSelection.photo(identifier: identifier).photoIdentifier, identifier)
    }

    func testStorageRoundTripsAndReaderDoesNotRepairMissingRecord() throws {
        let suiteName = "WidgetAppearanceStorageTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let storage = WidgetAppearanceStorage(defaults: defaults)

        XCTAssertEqual(storage.background, .native)
        XCTAssertNil(defaults.data(forKey: WidgetAppearanceStorage.backgroundKey))
        XCTAssertTrue(storage.writeBackground(.color(hex: "#2466E6")))
        XCTAssertEqual(storage.background, .color(hex: "#2466E6"))
        XCTAssertFalse(storage.writeBackground(.color(hex: "#12GG56")))
        XCTAssertEqual(storage.background, .color(hex: "#2466E6"))
        XCTAssertTrue(storage.writeProAccess(.allowed))
        XCTAssertEqual(storage.proAccess, .allowed)
    }

    func testMissingAppGroupDefaultsCannotWriteOrGrant() {
        let storage = WidgetAppearanceStorage(defaults: nil)

        XCTAssertEqual(storage.background, .native)
        XCTAssertEqual(storage.proAccess, .unknown)
        XCTAssertFalse(storage.writeBackground(.color(hex: "#2466E6")))
        XCTAssertFalse(storage.writeProAccess(.allowed))
    }
}
