import XCTest

/// The paywall must show every plan, the CTA and the required legal links without scrolling at default text size.
final class ProPaywallUITests: XCTestCase {
    private var evidenceDirectory: URL? {
        ProcessInfo.processInfo.environment["MACROS_EVIDENCE_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    override func setUp() {
        continueAfterFailure = false
    }

    override var executionTimeAllowance: TimeInterval {
        get { 90 }
        set { super.executionTimeAllowance = newValue }
    }

    func testPaywallFitsWithoutScrolling() {
        let app = launchPaywall()
        for plan in ["yearly", "monthly", "lifetime"] {
            XCTAssertTrue(app.buttons["pro.plan.\(plan)"].isHittable, "\(plan) row not hittable")
        }
        XCTAssertTrue(ctaIsHittable(app), "CTA not hittable")
        XCTAssertTrue(app.links["Terms of Use"].isHittable, "Terms not hittable")
        XCTAssertTrue(app.links["Privacy Policy"].isHittable, "Privacy not hittable")
        save(app, "paywall")
    }

    func testSettingsPaywallScreenshot() {
        let app = XCUIApplication()
        app.launchEnvironment["MACROS_UI_FIXTURE"] = "1"
        app.launchEnvironment["MACROS_FIXTURE_PRO"] = "0"
        app.launch()
        XCTAssertTrue(app.buttons["Open settings"].waitForExistence(timeout: 30))
        app.buttons["Open settings"].tap()
        let proRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'MACROS Pro'")).firstMatch
        XCTAssertTrue(proRow.waitForExistence(timeout: 10))
        proRow.tap()
        XCTAssertTrue(app.staticTexts["MACROS Pro"].waitForExistence(timeout: 10))
        for plan in ["yearly", "monthly", "lifetime"] {
            XCTAssertTrue(app.buttons["pro.plan.\(plan)"].isHittable)
        }
        XCTAssertTrue(ctaIsHittable(app))
        XCTAssertTrue(app.links["Terms of Use"].isHittable)
        XCTAssertTrue(app.links["Privacy Policy"].isHittable)
        save(app, "settings-paywall")
    }

    func testPaywallAtLargestAccessibilityTextSizeStillScrollsToLegalLinks() {
        let app = launchPaywall(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.buttons["pro.plan.yearly"].exists)
        save(app, "paywall-ax5")
        for _ in 0..<6 where !app.links["Privacy Policy"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.links["Privacy Policy"].isHittable, "Privacy not reachable by scrolling")
    }

    private func ctaIsHittable(_ app: XCUIApplication) -> Bool {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Subscribe for' OR label BEGINSWITH 'Buy lifetime' OR label == 'Start Free Trial'"))
            .firstMatch.isHittable
    }

    private func launchPaywall(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += arguments
        app.launchEnvironment["MACROS_UI_FIXTURE"] = "1"
        app.launchEnvironment["MACROS_FIXTURE_PRO"] = "0"
        app.launchEnvironment["MACROS_FIXTURE_MEAL_TRIAL_USED"] = "5"
        app.launch()
        XCTAssertTrue(app.buttons["Add Food"].waitForExistence(timeout: 30), "Home did not load")
        app.buttons["Add Food"].tap()
        let entry = app.buttons["scan-meal"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "Scan entry missing")
        entry.tap()
        XCTAssertTrue(app.staticTexts["MACROS Pro"].waitForExistence(timeout: 10), "Paywall missing")
        XCTAssertTrue(app.buttons["pro.plan.lifetime"].waitForExistence(timeout: 15), "Plans missing")
        return app
    }

    private func save(_ app: XCUIApplication, _ name: String) {
        guard let evidenceDirectory else { return }
        try? FileManager.default.createDirectory(at: evidenceDirectory, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: evidenceDirectory.appending(path: "\(name).png"))
    }
}
