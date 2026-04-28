#if os(iOS)
import SwiftUI
import Vision
import VisionKit

struct BarcodeLiveScannerView: UIViewControllerRepresentable {
    let onBarcodeScanned: (String) -> Void
    let onStartFailed: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeScanned: onBarcodeScanned)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: BarcodeScanConfiguration.packagedFoodSymbologies)],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if uiViewController.isScanning == false {
            do {
                try uiViewController.startScanning()
            } catch {
                onStartFailed(error)
            }
        }
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onBarcodeScanned: (String) -> Void
        private var hasScannedBarcode = false

        init(onBarcodeScanned: @escaping (String) -> Void) {
            self.onBarcodeScanned = onBarcodeScanned
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard hasScannedBarcode == false else { return }

            for item in addedItems {
                guard case let .barcode(barcode) = item,
                    let payload = barcode.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !payload.isEmpty
                else {
                    continue
                }

                hasScannedBarcode = true
                dataScanner.stopScanning()
                onBarcodeScanned(payload)
                return
            }
        }
    }
}
#endif
