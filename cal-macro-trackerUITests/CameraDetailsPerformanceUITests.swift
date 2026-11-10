import OSLog
import XCTest

/// Photo-import path of the camera: result card, Details, focus a macro field, type, scroll.
final class CameraDetailsPerformanceUITests: XCTestCase {
    private let markers = Logger(subsystem: "perf.camera", category: "phase")

    override func setUp() {
        continueAfterFailure = false
    }

    func testFocusTypeAndScrollInExpandedDetails() throws {
        let app = launchCameraWithLabelPhoto()
        let details = app.buttons["Edit details"]
        XCTAssertTrue(details.waitForExistence(timeout: 30), "Label result card never appeared")
        details.tap()

        let protein = app.textFields["Protein"]
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
