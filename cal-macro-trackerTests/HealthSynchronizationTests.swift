import HealthKit
import XCTest
@testable import cal_macro_tracker

final class HealthSynchronizationTests: XCTestCase {
    func testNutritionWritesIncludeOnlyAuthorizedTypes() {
        let authorized = HealthNutritionAuthorization.authorizedIdentifiers(
            statuses: [
                .dietaryEnergyConsumed: .sharingAuthorized,
                .dietaryProtein: .sharingDenied,
                .dietaryCarbohydrates: .sharingAuthorized,
                .dietaryFatTotal: .notDetermined
            ])

        XCTAssertEqual(authorized, [.dietaryEnergyConsumed, .dietaryCarbohydrates])
    }

    func testHealthImportGenerationRejectsStoppedAndOlderCallbacks() {
        var lifecycle = HealthQueryLifecycle()
        let first = lifecycle.start()
        XCTAssertTrue(lifecycle.accepts(first))

        lifecycle.stop()
        XCTAssertFalse(lifecycle.accepts(first))

        let second = lifecycle.start()
        XCTAssertNotEqual(first, second)
        XCTAssertFalse(lifecycle.accepts(first))
        XCTAssertTrue(lifecycle.accepts(second))
    }
}
