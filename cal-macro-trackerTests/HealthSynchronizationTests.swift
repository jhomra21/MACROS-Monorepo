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
}
