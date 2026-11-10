import UIKit
import Vision
import XCTest

final class ShareScreenUITests: XCTestCase {
    private static let sizes: [(name: String, pixels: CGSize)] = [
        ("Story", CGSize(width: 1080, height: 1920)),
        ("Post", CGSize(width: 1080, height: 1350)),
        ("Square", CGSize(width: 1080, height: 1080)),
    ]
    private static let details = ["Rings", "Macros", "Full"]
    private static let defaultCaption = "My macros today, tracked with MACROS. macrosios.com"
    private static let demoFoodNames = [
        "oatmeal", "yogurt", "chicken", "protein bar", "rice bowl", "scrambled", "toast", "salmon", "almonds",
        "sandwich", "cottage", "pasta", "black beans", "sweet potato", "peanut butter", "rice cakes",
    ]

    private var exportDirectory: URL {
        let root = ProcessInfo.processInfo.environment["MACROS_EVIDENCE_DIR"] ?? "/tmp/macros-share-p2-exports"
        return URL(fileURLWithPath: root, isDirectory: true).appending(path: "share-exports")
    }

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Share sheet

    func testSheetOpensWithDefaultsAndPreviewTracksEverySizeAndDetail() throws {
        let app = launchHome()
        openShareSheet(app)

        let preview = app.otherElements["share-preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "Preview missing")
        XCTAssertEqual(preview.value as? String, "Story, Macros", "Defaults are Story and Macros")
        XCTAssertEqual(captionField(app).value as? String, Self.defaultCaption)

        var seen = Set<String>()
        for size in Self.sizes {
            for detail in Self.details {
                app.segmentedControls["share-size-picker"].buttons[size.name].tap()
                app.segmentedControls["share-detail-picker"].buttons[detail].tap()
                let expected = "\(size.name), \(detail)"
                XCTAssertEqual(preview.value as? String, expected)
                seen.insert(expected)
            }
        }
        XCTAssertEqual(seen.count, 9)
    }

    func testShareCopiesEditedCaptionAndPresentsShareSheet() throws {
        try? FileManager.default.removeItem(at: exportDirectory.appending(path: "pasteboard.txt"))
        let app = launchHome()
        openShareSheet(app)

        app.buttons["share-submit"].tap()

        XCTAssertTrue(activitySheet(app).waitForExistence(timeout: 10), "System share sheet missing")
        XCTAssertEqual(copiedCaption(), Self.defaultCaption)
        dismissActivitySheet(app)
        XCTAssertTrue(app.staticTexts["Caption copied. Paste it in your post."].exists, "Copied note missing")

        let field = captionField(app)
        field.tap()
        field.typeText("EDITED ")
        XCTAssertFalse(app.staticTexts["Caption copied. Paste it in your post."].exists, "Note should clear on edit")
        app.buttons["share-submit"].tap()
        XCTAssertTrue(activitySheet(app).waitForExistence(timeout: 10))
        let edited = try XCTUnwrap(copiedCaption())
        XCTAssertTrue(edited.contains("EDITED "), "Copied caption ignored the edit: \(edited)")
        XCTAssertNotEqual(edited, Self.defaultCaption)
    }

    func testExportsEverySizeAndDetailAtExactPixelsWithoutFoodNames() throws {
        let app = launchHome()
        openShareSheet(app)
        try? FileManager.default.removeItem(at: exportDirectory)

        for size in Self.sizes {
            for detail in Self.details {
                app.segmentedControls["share-size-picker"].buttons[size.name].tap()
                app.segmentedControls["share-detail-picker"].buttons[detail].tap()
                app.buttons["share-submit"].tap()

                let file = exportDirectory.appending(path: "\(size.name)-\(detail).png")
                waitForFile(file)
                let image = try XCTUnwrap(UIImage(contentsOfFile: file.path), "\(file.lastPathComponent) unreadable")
                let cgImage = try XCTUnwrap(image.cgImage)
                XCTAssertEqual(CGSize(width: cgImage.width, height: cgImage.height), size.pixels, "\(size.name)-\(detail)")
                XCTAssertTrue(cornersAreOpaque(cgImage), "\(size.name)-\(detail) has transparent corners")

                let text = try recognizedText(in: cgImage).lowercased()
                for food in Self.demoFoodNames {
                    XCTAssertFalse(text.contains(food), "\(size.name)-\(detail) shows food name \(food)")
                }
                let weekday = Date.now.formatted(.dateTime.weekday(.wide)).lowercased()
                XCTAssertTrue(text.contains(weekday), "OCR did not read the header in \(size.name)-\(detail): \(text)")
                if detail != "Rings" {
                    XCTAssertTrue(text.contains("protein"), "\(size.name)-\(detail) lacks macro columns: \(text)")
                }
                if detail == "Full" {
                    XCTAssertTrue(text.contains("fiber"), "\(size.name)-\(detail) lacks secondary nutrition: \(text)")
                } else {
                    XCTAssertFalse(text.contains("fiber"), "\(size.name)-\(detail) shows secondary nutrition")
                }
                dismissActivitySheet(app)
            }
        }
    }

    // MARK: Person row

    func testPersonRowForFreeUserLeadsToSetupWithoutCount() throws {
        let app = launchHome(pro: false, sharing: true)
        openShareSheet(app)

        let row = app.buttons["share-person-row"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Share with a person"))
        XCTAssertFalse(row.label.contains("2 people"))
        row.tap()
        XCTAssertTrue(app.switches["Sharing"].waitForExistence(timeout: 5), "Free users land on setup")
    }

    func testPersonRowForProWithSharingOffLeadsToSetup() throws {
        let app = launchHome(pro: true, sharing: false)
        openShareSheet(app)

        let row = app.buttons["share-person-row"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertFalse(row.label.contains("2 people"))
        row.tap()
        XCTAssertTrue(app.switches["Sharing"].waitForExistence(timeout: 5), "Sharing off lands on setup")
    }

    func testPersonRowForProWithSharingOnShowsCountAndOpensDashboard() throws {
        let app = launchHome(pro: true, sharing: true)
        openShareSheet(app)

        let row = app.buttons["share-person-row"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        expectLabel(row, contains: "2 people")
        row.tap()
        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 10), "Dashboard lists connected people")
        XCTAssertFalse(app.navigationBars["Share"].exists, "Share sheet should be dismissed")
    }

    func testOfflineRemoteNeverBlocksTheImagePath() throws {
        let app = launchHome(pro: true, sharing: true, remote: "offline")
        openShareSheet(app)

        let row = app.buttons["share-person-row"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertFalse(row.label.contains("2 people"))
        XCTAssertTrue(app.buttons["share-submit"].isEnabled)

        app.buttons["share-submit"].tap()
        XCTAssertTrue(activitySheet(app).waitForExistence(timeout: 10), "Image share must work offline")
    }

    // MARK: Helpers

    private func launchHome(pro: Bool = false, sharing: Bool = false, remote: String = "online") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MACROS_UI_FIXTURE"] = "1"
        app.launchEnvironment["MACROS_FIXTURE_PRO"] = pro ? "1" : "0"
        app.launchEnvironment["MACROS_FIXTURE_SHARING"] = sharing ? "on" : "off"
        app.launchEnvironment["MACROS_FIXTURE_REMOTE"] = remote
        app.launchEnvironment["MACROS_EXPORT_DIR"] = exportDirectory.path
        app.launch()
        XCTAssertTrue(app.buttons["Share daily summary"].waitForExistence(timeout: 30), "Home did not load")
        return app
    }

    private func openShareSheet(_ app: XCUIApplication) {
        app.buttons["Share daily summary"].tap()
        let navigationBar = app.navigationBars["Share"]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5), "Share sheet did not open")
        // The medium detent lazily builds only the visible rows; expand so every control exists.
        navigationBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)))
        XCTAssertEqual(app.buttons["Sheet Grabber"].value as? String, "Expanded", "Sheet did not expand")
    }

    /// The app reads its own pasteboard back after copying; the runner cannot read it without blocking on the paste prompt.
    private func copiedCaption() -> String? {
        try? String(contentsOf: exportDirectory.appending(path: "pasteboard.txt"), encoding: .utf8)
    }

    private func captionField(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["share-caption"]
    }

    private func activitySheet(_ app: XCUIApplication) -> XCUIElement {
        app.otherElements["ActivityListView"]
    }

    private func dismissActivitySheet(_ app: XCUIApplication) {
        let sheet = activitySheet(app)
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "System share sheet missing")
        let close = app.buttons["header.closeButton"]
        XCTAssertTrue(close.waitForExistence(timeout: 10), "Share sheet close button missing")
        close.tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 10), "System share sheet did not close")
    }

    private func expectLabel(_ element: XCUIElement, contains text: String, timeout: TimeInterval = 10) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout)
        XCTAssertEqual(result, .completed, "Label \(element.label) never contained \(text)")
    }

    private func waitForFile(_ url: URL, timeout: TimeInterval = 20) {
        let predicate = NSPredicate { _, _ in FileManager.default.fileExists(atPath: url.path) }
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(url.lastPathComponent) was not exported")
    }

    private func cornersAreOpaque(_ image: CGImage) -> Bool {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard
            let context = CGContext(
                data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)].allSatisfy { x, y in
            pixels[(y * width + x) * 4 + 3] == 255
        }
    }

    private func recognizedText(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
