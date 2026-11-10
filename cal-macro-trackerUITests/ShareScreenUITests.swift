import UIKit
import Vision
import XCTest

final class ShareScreenUITests: XCTestCase {
    private static let sizes: [(name: String, pixels: CGSize)] = [
        ("Story", CGSize(width: 1080, height: 1920)),
        ("Post", CGSize(width: 1080, height: 1350)),
        ("Square", CGSize(width: 1080, height: 1080))
    ]
    private static let details = ["Rings", "Macros", "Full"]
    private static let defaultCaption = "My macros today, tracked with MACROS. macrosios.com"
    private static let demoFoodNames = [
        "oatmeal", "yogurt", "chicken", "protein bar", "rice bowl", "scrambled", "toast", "salmon", "almonds",
        "sandwich", "cottage", "pasta", "black beans", "sweet potato", "peanut butter", "rice cakes"
    ]

    private var exportDirectory: URL {
        let root = ProcessInfo.processInfo.environment["MACROS_EVIDENCE_DIR"] ?? "/tmp/macros-share-p2-exports"
        return URL(fileURLWithPath: root, isDirectory: true).appending(path: "share-exports")
    }

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Share sheet

    func testSheetOpensWithDefaultsAndPreviewTracksStory() { assertPreviewTracks(size: "Story", showsDefaults: true) }
    func testPreviewTracksPost() { assertPreviewTracks(size: "Post") }
    func testPreviewTracksSquare() { assertPreviewTracks(size: "Square") }

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

    func testExportsStoryAtExactPixelsWithoutFoodNames() throws { try assertExports(size: Self.sizes[0]) }
    func testExportsPostAtExactPixelsWithoutFoodNames() throws { try assertExports(size: Self.sizes[1]) }
    func testExportsSquareAtExactPixelsWithoutFoodNames() throws { try assertExports(size: Self.sizes[2]) }

    // MARK: Menu and full height

    func testSheetOpensAtFullHeightWithoutPersonRow() {
        let app = launchHome(pro: true, sharing: true)
        openShareSheet(app)

        XCTAssertTrue(captionField(app).isHittable, "Caption field should be reachable without dragging")
        XCTAssertTrue(app.buttons["Copy caption"].isHittable, "Copy caption should be reachable without dragging")
        XCTAssertFalse(app.buttons["share-person-row"].exists, "Person row belongs in the menu, not the sheet")
    }

    func testMenuListsBothChoicesBeforeAnySheet() {
        let app = launchHome()
        app.buttons["Share daily summary"].tap()

        XCTAssertTrue(menuItem(app, "Post an image").waitForExistence(timeout: 5), "Post an image missing")
        XCTAssertTrue(menuItem(app, "Live sharing").exists, "Live sharing missing")
        expectLabel(menuItem(app, "Post an image"), contains: "Your rings and macros for social media")
        expectLabel(menuItem(app, "Live sharing"), contains: "Your macros with people you choose")
        XCTAssertFalse(app.navigationBars["Share"].exists, "The menu comes first, not the sheet")
    }

    func testLiveSharingForFreeUserLeadsToSetupWithoutCount() throws {
        let app = launchHome(pro: false, sharing: true)
        app.buttons["Share daily summary"].tap()

        let item = menuItem(app, "Live sharing")
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        XCTAssertFalse(item.label.contains("people"))
        item.tap()
        XCTAssertTrue(app.switches["Sharing"].waitForExistence(timeout: 5), "Free users land on setup")
    }

    func testLiveSharingForProWithSharingOffLeadsToSetup() throws {
        let app = launchHome(pro: true, sharing: false)
        app.buttons["Share daily summary"].tap()

        let item = menuItem(app, "Live sharing")
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        XCTAssertFalse(item.label.contains("people"))
        item.tap()
        XCTAssertTrue(app.switches["Sharing"].waitForExistence(timeout: 5), "Sharing off lands on setup")
    }

    func testLiveSharingForProWithSharingOnShowsCountAndOpensDashboard() throws {
        let app = launchHome(pro: true, sharing: true)
        // Let the scripted dashboard load before the menu is built.
        Thread.sleep(forTimeInterval: 2)
        app.buttons["Share daily summary"].tap()

        let item = menuItem(app, "Live sharing")
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        expectLabel(item, contains: "2 people")
        item.tap()
        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 10), "Dashboard lists connected people")
        XCTAssertFalse(app.navigationBars["Share"].exists, "No share sheet should be up")
    }

    func testOfflineRemoteNeverBlocksTheImagePath() throws {
        let app = launchHome(pro: true, sharing: true, remote: "offline")
        openShareSheet(app)

        XCTAssertTrue(app.buttons["share-submit"].isEnabled)

        app.buttons["share-submit"].tap()
        XCTAssertTrue(activitySheet(app).waitForExistence(timeout: 10), "Image share must work offline")
    }

    // MARK: Helpers

    private func assertPreviewTracks(size: String, showsDefaults: Bool = false) {
        let app = launchHome()
        openShareSheet(app)

        let preview = app.otherElements["share-preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "Preview missing")
        if showsDefaults {
            XCTAssertEqual(preview.value as? String, "Story, Macros", "Defaults are Story and Macros")
            XCTAssertEqual(captionField(app).value as? String, Self.defaultCaption)
        }

        app.segmentedControls["share-size-picker"].buttons[size].tap()
        for detail in Self.details {
            app.segmentedControls["share-detail-picker"].buttons[detail].tap()
            XCTAssertEqual(preview.value as? String, "\(size), \(detail)")
        }
    }

    private func assertExports(size: (name: String, pixels: CGSize)) throws {
        let app = launchHome()
        openShareSheet(app)
        app.segmentedControls["share-size-picker"].buttons[size.name].tap()

        for detail in Self.details {
            let file = exportDirectory.appending(path: "\(size.name)-\(detail).png")
            try? FileManager.default.removeItem(at: file)
            app.segmentedControls["share-detail-picker"].buttons[detail].tap()
            app.buttons["share-submit"].tap()

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
        let item = menuItem(app, "Post an image")
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Share menu did not open")
        item.tap()
        XCTAssertTrue(app.navigationBars["Share"].waitForExistence(timeout: 5), "Share sheet did not open")
    }

    /// Menu rows carry their subtitle in the label, so match on the title prefix.
    private func menuItem(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
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
