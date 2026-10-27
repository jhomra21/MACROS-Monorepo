#if os(iOS)
import UIKit
import Vision

enum BarcodeScanConfiguration {
    nonisolated static let packagedFoodSymbologies: [VNBarcodeSymbology] = [.ean13, .ean8, .upce]
}

enum BarcodeImageScannerError: LocalizedError {
    case noBarcodeFound
    case detectionUnavailable(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noBarcodeFound:
            "No barcode was found in that image."
        case let .detectionUnavailable(underlying):
            "Barcode detection is unavailable: \(underlying.localizedDescription)"
        }
    }
}

struct BarcodeImageScanner {
    func scanBarcode(from image: UIImage) async throws -> String {
        let image = SendableScanImage(value: image)
        return try await Task.detached(priority: .userInitiated) {
            try scanBarcodeImageSync(from: image.value)
        }.value
    }
}

nonisolated private func scanBarcodeImageSync(from image: UIImage) throws -> String {
    let visionImage = try ScanImageLoading.makeVisionImage(from: image)
    let request = VNDetectBarcodesRequest()
    request.symbologies = BarcodeScanConfiguration.packagedFoodSymbologies

    let handler = VNImageRequestHandler(cgImage: visionImage.cgImage, orientation: visionImage.orientation)
    try performBarcodeDetection(request, with: handler)

    guard
        let barcode = request.results?
            .compactMap({ $0.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty })
    else {
        throw BarcodeImageScannerError.noBarcodeFound
    }

    return barcode
}

nonisolated func performBarcodeDetection(
    _ request: VNDetectBarcodesRequest,
    with handler: VNImageRequestHandler,
    perform: (VNImageRequestHandler, [VNRequest]) throws -> Void = { try $0.perform($1) }
) throws {
    do {
        try perform(handler, [request])
    } catch {
        throw BarcodeImageScannerError.detectionUnavailable(underlying: error)
    }
}
#endif
