import OSLog
import XCTest

/// Photo-import path of the camera: result card, Details, focus a macro field, type, scroll.
final class CameraDetailsPerformanceUITests: XCTestCase {
    private let markers = Logger(subsystem: "perf.camera", category: "phase")

    override func setUp() {
        continueAfterFailure = false
    }

    /// Phone layout scrolls the editor in each iteration, and five iterations exceed the 60-second default. Stay at the runbook's 90-second maximum.
    override var executionTimeAllowance: TimeInterval {
        get { 90 }
        set { super.executionTimeAllowance = newValue }
    }

    func testFocusTypeAndScrollInExpandedDetails() throws {
        let app = launchCameraWithLabelPhoto()
        let details = app.buttons["Edit details"]
        XCTAssertTrue(details.waitForExistence(timeout: 30), "Label result card never appeared")
        details.tap()

        let editor = app.collectionViews["camera-result-card"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "Inline editor missing")
        let protein = app.textFields["Protein"]
        revealProtein(protein, in: editor)
        XCTAssertTrue(protein.waitForExistence(timeout: 10), "Protein field missing in the inline editor")

        var focusTimes: [TimeInterval] = []
        var typeTimes: [TimeInterval] = []
        var hasTypedText = false
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(
            metrics: [XCTClockMetric(), XCTCPUMetric(application: app), XCTHitchMetric(application: app)],
            options: options
        ) {
            if hasTypedText {
                protein.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5))
                app.buttons["Done"].tap()
                XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10), "Keyboard did not dismiss")
            }
            hasTypedText = true
            revealProtein(protein, in: editor)
            mark("begin")
            startMeasuring()
            var clock = Date()
            protein.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), "Keyboard did not appear")
            focusTimes.append(Date().timeIntervalSince(clock))
            mark("focused")
            clock = Date()
            protein.typeText("12345")
            typeTimes.append(Date().timeIntervalSince(clock))
            mark("typed")
            app.swipeUp()
            app.swipeDown()
            mark("end")
        }
        print("PERF_FOCUS \(focusTimes.map { String(format: "%.3f", $0) })")
        print("PERF_TYPE \(typeTimes.map { String(format: "%.3f", $0) })")
    }

    private func mark(_ name: String) {
        markers.notice("phase \(name, privacy: .public)")
    }

    /// On phone the inline editor is a fixed-height list: nutrient rows below the fold are not
    /// in the accessibility tree until scrolled into view. Scroll before the measured block.
    private func revealProtein(_ protein: XCUIElement, in editor: XCUIElement) {
        for _ in 0..<10 where !protein.exists {
            editor.swipeUp(velocity: .slow)
        }
    }

    private func launchCameraWithLabelPhoto() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MACROS_UI_FIXTURE"] = "1"
        app.launchEnvironment["MACROS_FIXTURE_CAMERA_IMAGE"] = labelPhotoPath()
        app.launch()
        let camera = app.buttons["Camera"]
        XCTAssertTrue(camera.waitForExistence(timeout: 30), "Home did not load")
        camera.tap()
        return app
    }

    /// The simulator app reads the host filesystem, so a temp copy of the bundled still is enough.
    private func labelPhotoPath() -> String {
        let source = Bundle(for: Self.self).url(forResource: "oat-crunch-nutrition-label", withExtension: "png")!
        let destination = FileManager.default.temporaryDirectory.appending(path: "camera-perf-label.png")
        try? FileManager.default.removeItem(at: destination)
        try! FileManager.default.copyItem(at: source, to: destination)
        return destination.path
    }
}
