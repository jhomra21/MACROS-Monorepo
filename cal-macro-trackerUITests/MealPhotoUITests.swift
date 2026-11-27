import XCTest

/// Meal photo scanning against the DEBUG mock (no network): scan, review, edit, oil prompt, log.
final class MealPhotoUITests: XCTestCase {
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

    func testScanEditOilPromptLogsToToday() throws {
        let app = launch(mock: "typical-plate", pro: true)
        openScanner(app)

        XCTAssertTrue(app.staticTexts["Grilled salmon"].waitForExistence(timeout: 20), "Review screen missing")
        XCTAssertTrue(app.staticTexts["Brown rice"].exists)
        save(app, "review")

        let grams = app.textFields["Brown rice grams"]
        grams.tap()
        grams.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "150")
        app.buttons["Done"].tap()

        app.buttons["Log Meal"].tap()
        XCTAssertTrue(app.alerts["Did you add oil, butter or dressing?"].waitForExistence(timeout: 5), "Oil prompt missing")
        save(app, "oil-prompt")
        app.alerts.buttons["Yes"].tap()
        save(app, "oil-after-yes")
        XCTAssertTrue(scrollTo(oilLabel(app), in: app), "Oil item missing")
        save(app, "oil-item")

        app.buttons["Log Meal"].tap()
        XCTAssertTrue(app.navigationBars["Scan a Meal"].waitForNonExistence(timeout: 20), "Add Food did not close after logging")
        XCTAssertTrue(scrollTo(oilLabel(app), in: app), "Logged oil is missing from Today")
        XCTAssertTrue(scrollTo(app.staticTexts["Brown rice"], in: app), "Logged rice is missing from Today")
    }

    func testReviewAtLargestAccessibilityTextSize() {
        let app = launch(mock: "typical-plate", pro: true, extraArguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        openScanner(app)
        XCTAssertTrue(app.staticTexts["Grilled salmon"].waitForExistence(timeout: 20))
        let logButton = app.buttons["Log Meal"]
        XCTAssertTrue(logButton.exists)
        XCTAssertTrue(app.textFields["Grilled salmon grams"].exists)
        save(app, "review-ax5")
        app.swipeUp()
        save(app, "review-ax5-amount")
        XCTAssertTrue(app.buttons["Log Meal"].isHittable)
    }

    func testVolumeOnlyDrinkRequiresQuantity() {
        let app = launch(mock: "volume-only-drink", pro: true)
        openScanner(app)
        XCTAssertTrue(app.staticTexts["Orange juice"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["About 250 ml. Enter how much you had."].exists)
        XCTAssertFalse(app.buttons["Log Meal"].isEnabled, "Log must wait for a confirmed quantity")
    }

    func testNotFoodOffersSearchInstead() {
        let app = launch(mock: "not-food", pro: true)
        openScanner(app)
        XCTAssertTrue(app.staticTexts["No food found"].waitForExistence(timeout: 20))
        app.buttons["Search Instead"].tap()
        XCTAssertTrue(app.buttons["scan-meal"].waitForExistence(timeout: 5), "Back on Add Food search")
    }

    func testErrorKeepsManualLoggingAvailable() {
        let app = launch(mock: "error", pro: true)
        openScanner(app)
        XCTAssertTrue(app.staticTexts["Scan didn't work"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Try Again"].exists)
        app.buttons["Search Instead"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5), "Normal food search missing")
    }

    func testExhaustedTrialShowsPaywall() {
        let app = launch(mock: "typical-plate", pro: false, trialUsed: 5)
        app.buttons["Add Food"].tap()
        let entry = app.buttons["scan-meal"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        XCTAssertTrue(entry.label.contains("Pro"), entry.label)
        XCTAssertTrue(entry.label.contains("0 free scans"), entry.label)
        entry.tap()
        XCTAssertTrue(app.staticTexts["MACROS Pro"].waitForExistence(timeout: 10), "Paywall missing")
        save(app, "trial-paywall")
    }

    func testTrialShowsRemainingScans() {
        let app = launch(mock: "typical-plate", pro: false, trialUsed: 2)
        app.buttons["Add Food"].tap()
        let entry = app.buttons["scan-meal"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        XCTAssertTrue(entry.label.contains("3 free scans left"), entry.label)
        save(app, "entry-trial")
    }

    // MARK: Helpers

    private func launch(
        mock: String, pro: Bool, trialUsed: Int = 0, extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-MealPhotoMockResponse", mock] + extraArguments
        app.launchEnvironment["MACROS_UI_FIXTURE"] = "1"
        app.launchEnvironment["MACROS_FIXTURE_PRO"] = pro ? "1" : "0"
        app.launchEnvironment["MACROS_FIXTURE_MEAL_TRIAL_USED"] = String(trialUsed)
        app.launchEnvironment["MACROS_FIXTURE_CAMERA_IMAGE"] = platePhotoPath()
        app.launch()
        XCTAssertTrue(app.buttons["Add Food"].waitForExistence(timeout: 30), "Home did not load")
        return app
    }

    private func openScanner(_ app: XCUIApplication) {
        app.buttons["Add Food"].tap()
        let entry = app.buttons["scan-meal"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "Scan a meal entry missing")
        entry.tap()
        let library = app.buttons["Choose from Library"]
        XCTAssertTrue(library.waitForExistence(timeout: 5), "Menu missing")
        library.tap()
    }

    /// A catalog match is titled "Olive Oil"; the built-in fallback is "Olive oil".
    private func oilLabel(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "olive oil")).firstMatch
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<6 where !element.exists { app.swipeUp() }
        return element.exists
    }

    /// The simulator app reads the host filesystem, so a temp copy of the bundled still is enough.
    private func platePhotoPath() -> String {
        let source = Bundle(for: Self.self).url(forResource: "oat-crunch-nutrition-label", withExtension: "png")!
        let destination = FileManager.default.temporaryDirectory.appending(path: "meal-photo-plate.png")
        try? FileManager.default.removeItem(at: destination)
        try! FileManager.default.copyItem(at: source, to: destination)
        return destination.path
    }

    private func save(_ app: XCUIApplication, _ name: String) {
        guard let evidenceDirectory else { return }
        try? FileManager.default.createDirectory(at: evidenceDirectory, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: evidenceDirectory.appending(path: "\(name).png"))
    }
}
