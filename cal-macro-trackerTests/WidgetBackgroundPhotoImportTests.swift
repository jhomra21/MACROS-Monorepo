#if os(iOS)
import Foundation
import UIKit
import XCTest
@testable import cal_macro_tracker

// Failure inventory: missing or mismatched protection must fail, not skip.
// Denied access must leave native selection without a record. Replacement and
// reset must remove only owned photos; cleanup must not touch other files.
@MainActor
final class WidgetBackgroundPhotoImportTests: XCTestCase {
    func testCommitWritesProtectedBackupExcludedPhotoAndRestoreDefaultRemovesIt() throws {
        let suiteName = "WidgetBackgroundPhotoImportTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let storage = WidgetAppearanceStorage(defaults: defaults)
        XCTAssertTrue(storage.writeProAccess(.allowed))
        let jpeg = try makeTinyJPEG()

        let photoID = try WidgetBackgroundPhotoImport.commit(jpeg, storage: storage)
        let url = try XCTUnwrap(storage.photoURL(for: photoID))
        defer { removeOwnedPhotoIfPresent(url) }

        XCTAssertEqual(storage.background, .photo(identifier: photoID))
        XCTAssertEqual(url.lastPathComponent, "\(photoID.uuidString).jpg")
        XCTAssertEqual(try Data(contentsOf: url), jpeg)

        var resourceURL = url
        resourceURL.removeAllCachedResourceValues()
        let values = try resourceURL.resourceValues(
            forKeys: [.fileProtectionKey, .isExcludedFromBackupKey, .fileSizeKey]
        )
        XCTAssertEqual(values.fileProtection, .completeUntilFirstUserAuthentication)
        XCTAssertEqual(values.isExcludedFromBackup, true)
        XCTAssertEqual(values.fileSize, jpeg.count)

        try WidgetBackgroundPhotoImport.writeSelection(.native, storage: storage)
        XCTAssertEqual(storage.background, .native)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testDeniedCommitLeavesSelectionNativeWithoutSelectionRecord() throws {
        let suiteName = "WidgetBackgroundPhotoImportTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let storage = WidgetAppearanceStorage(defaults: defaults)
        XCTAssertTrue(storage.writeProAccess(.denied))
        let jpeg = try makeTinyJPEG()

        XCTAssertThrowsError(try WidgetBackgroundPhotoImport.commit(jpeg, storage: storage)) { error in
            guard let importError = error as? WidgetBackgroundPhotoImport.ImportError,
                case .unavailableStorage = importError
            else { return XCTFail("Expected unavailableStorage, got \(error)") }
        }
        XCTAssertEqual(storage.background, .native)
        XCTAssertNil(defaults.data(forKey: WidgetAppearanceStorage.backgroundKey))
    }

    func testReplacingPhotoRemovesOnlyPreviousOwnedPhoto() throws {
        let suiteName = "WidgetBackgroundPhotoImportTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let storage = WidgetAppearanceStorage(defaults: defaults)
        XCTAssertTrue(storage.writeProAccess(.allowed))
        let jpeg = try makeTinyJPEG()

        let firstID = try WidgetBackgroundPhotoImport.commit(jpeg, storage: storage)
        let firstURL = try XCTUnwrap(storage.photoURL(for: firstID))
        defer { removeOwnedPhotoIfPresent(firstURL) }
        let secondID = try WidgetBackgroundPhotoImport.commit(jpeg, storage: storage)
        let secondURL = try XCTUnwrap(storage.photoURL(for: secondID))
        defer { removeOwnedPhotoIfPresent(secondURL) }

        XCTAssertFalse(FileManager.default.fileExists(atPath: firstURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondURL.path))
        XCTAssertEqual(storage.background, .photo(identifier: secondID))

        try WidgetBackgroundPhotoImport.writeSelection(.native, storage: storage)
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondURL.path))
    }

    private func makeTinyJPEG() throws -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8), format: format)
        let image = renderer.image { context in
            UIColor(red: 0.14, green: 0.4, blue: 0.9, alpha: 1).setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 1))
    }

    private func removeOwnedPhotoIfPresent(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            XCTFail("Could not remove test-owned widget photo: \(error)")
        }
    }
}
#endif
