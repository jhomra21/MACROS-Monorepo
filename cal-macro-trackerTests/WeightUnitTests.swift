import Foundation
import XCTest
@testable import cal_macro_tracker

final class WeightUnitTests: XCTestCase {
    func testRegionDefaultsAndLegacyProfilePrecedence() {
        for region in ["en_US", "en_GB"] {
            XCTAssertEqual(WeightUnit.initial(profileUnitSystem: nil, locale: Locale(identifier: region)), .pounds)
            XCTAssertEqual(WeightUnit.initial(profileUnitSystem: .metric, locale: Locale(identifier: region)), .kilograms)
        }
        XCTAssertEqual(WeightUnit.initial(profileUnitSystem: nil, locale: Locale(identifier: "de_DE")), .kilograms)
        XCTAssertEqual(WeightUnit.initial(profileUnitSystem: .imperial, locale: Locale(identifier: "de_DE")), .pounds)
    }

    func testConversionAndRepeatedSwitchesKeepPhysicalWeight() {
        let kilograms = WeightUnit.pounds.fromDisplay(180)
        XCTAssertEqual(kilograms, 81.6466266, accuracy: 1e-9)
        var value = 180.0
        for _ in 0..<100 {
            value = WeightUnit.kilograms.toDisplay(WeightUnit.pounds.fromDisplay(value))
            value = WeightUnit.pounds.toDisplay(WeightUnit.kilograms.fromDisplay(value))
        }
        XCTAssertEqual(value, 180, accuracy: 1e-9)
    }

    @MainActor
    func testPreferenceMigratesOnceAndDoesNotFollowLaterHeightChanges() throws {
        let suite = "WeightUnitTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        WeightUnit.initializeIfNeeded(profileUnitSystem: .imperial, defaults: defaults)
        WeightUnit.initializeIfNeeded(profileUnitSystem: .metric, defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: AppStorageKeys.weightUnit), WeightUnit.pounds.rawValue)
    }
}
