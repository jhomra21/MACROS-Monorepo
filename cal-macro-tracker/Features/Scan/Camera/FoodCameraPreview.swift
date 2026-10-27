#if os(iOS)
import SwiftUI
import Vision
import VisionKit

@MainActor
final class FoodCameraScannerController {
    let scanner: DataScannerViewController
    private let reset: () -> Void

    init(scanner: DataScannerViewController, reset: @escaping () -> Void) {
        self.scanner = scanner
        self.reset = reset
    }

    func startScanning() throws {
        guard scanner.isScanning == false else { return }
        reset()
        try scanner.startScanning()
    }

    func stopScanning() {
        scanner.stopScanning()
    }
}

struct FoodCameraPreview: UIViewControllerRepresentable {
    let onReady: (FoodCameraScannerController) -> Void
    let onBarcode: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcode: onBarcode)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: BarcodeScanConfiguration.packagedFoodSymbologies)],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        let coordinator = context.coordinator
        let controller = FoodCameraScannerController(scanner: scanner, reset: { [weak coordinator] in coordinator?.reset() })
        // Report readiness after SwiftUI finishes installing this controller.
        Task { @MainActor in onReady(controller) }
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onBarcode = onBarcode
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onBarcode: (String) -> Void
        private var hasReportedBarcode = false

        init(onBarcode: @escaping (String) -> Void) {
            self.onBarcode = onBarcode
        }

        func reset() {
            hasReportedBarcode = false
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard hasReportedBarcode == false else { return }
            for item in addedItems {
                guard case let .barcode(barcode) = item,
                    let value = barcode.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                    value.isEmpty == false
                else {
                    continue
                }
                hasReportedBarcode = true
                onBarcode(value)
                return
            }
        }
    }
}
#endif
