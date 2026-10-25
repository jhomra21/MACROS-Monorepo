import Foundation
import XCTest
@testable import cal_macro_tracker

@MainActor
final class ProEntitlementTests: XCTestCase {
    func testAllFeaturesRequirePro() {
        let entitlements = AppEntitlements()
        for feature in PaidFeature.allCases {
            XCTAssertFalse(entitlements.canUse(feature))
        }
        entitlements.update(pro: true, source: .lifetime, expiration: nil)
        for feature in PaidFeature.allCases {
            XCTAssertTrue(entitlements.canUse(feature))
        }
    }

    func testRevocationClearsSourceAndExpiration() {
        let entitlements = AppEntitlements()
        entitlements.update(pro: true, source: .yearly, expiration: Date().addingTimeInterval(600))
        entitlements.update(pro: false, source: nil, expiration: nil)
        XCTAssertFalse(entitlements.hasPro)
        XCTAssertNil(entitlements.proSource)
        XCTAssertNil(entitlements.proExpirationDate)
    }

    func testProductMappingExcludesUnknownProducts() {
        XCTAssertNil(ProSource(productID: "unrelated"))
        XCTAssertEqual(ProSource(productID: "fullunlock001"), .legacyFullUnlock)
        for plan in ProPlan.allCases {
            XCTAssertNotNil(ProSource(productID: plan.productID))
        }
    }

    func testLifetimePriorityIsHigherThanEitherSubscription() {
        XCTAssertGreaterThan(ProSource.lifetime.priority, ProSource.yearly.priority)
        XCTAssertGreaterThan(ProSource.legacyFullUnlock.priority, ProSource.monthly.priority)
    }
}
