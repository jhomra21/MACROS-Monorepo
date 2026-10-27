import UIKit
import Vision
import XCTest
@testable import cal_macro_tracker

@MainActor
final class BarcodeImageScannerTests: XCTestCase {
    func testRecognizesRealEAN13Fixture() async throws {
        let image = try image(named: "ean-737628064502")

        let barcode = try await BarcodeImageScanner().scanBarcode(from: image)

        XCTAssertEqual(barcode, "0737628064502")
    }

    func testZeroEAN13FixtureDoesNotResolveToRealProductCode() async throws {
        let image = try image(named: "ean-000000000000")

        do {
            let barcode = try await BarcodeImageScanner().scanBarcode(from: image)
            XCTAssertNotEqual(barcode, "0737628064502")
        } catch BarcodeImageScannerError.noBarcodeFound {
            // An invalid check digit must not resolve to a packaged product.
        }
    }

    func testImageWithoutBarcodeThrowsNoBarcodeFound() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 500, height: 500)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 500, height: 500))
        }

        do {
            _ = try await BarcodeImageScanner().scanBarcode(from: image)
            XCTFail("A blank image must not resolve a barcode.")
        } catch BarcodeImageScannerError.noBarcodeFound {
            // Expected.
        }
    }

    func testPerformFailureIsDistinguishableFromNoBarcode() throws {
        let image = try image(named: "ean-737628064502")
        let visionImage = try ScanImageLoading.makeVisionImage(from: image)
        let request = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(cgImage: visionImage.cgImage, orientation: visionImage.orientation)

        XCTAssertThrowsError(
            try performBarcodeDetection(request, with: handler) { _, _ in
                throw URLError(.notConnectedToInternet)
            }
        ) { error in
            guard case let BarcodeImageScannerError.detectionUnavailable(underlying) = error else {
                return XCTFail("Expected detectionUnavailable, received \(error)")
            }
            XCTAssertEqual((underlying as? URLError)?.code, .notConnectedToInternet)
        }
    }

    private func image(named name: String) throws -> UIImage {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "png"))
        return try XCTUnwrap(UIImage(contentsOfFile: url.path))
    }
}
