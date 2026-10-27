#if os(iOS)
import SwiftUI
import Vision
import VisionKit

struct FoodCameraPreview: UIViewControllerRepresentable {
    let isActive: Bool
    let onReady: (DataScannerViewController) -> Void
    let onBarcode: (String) -> Void
    let onFailure: (String) -> Void

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
        onReady(scanner)
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        guard scanner.isScanning != isActive else { return }
        if isActive {
            context.coordinator.reset()
            do {
                try scanner.startScanning()
            } catch {
                onFailure(error.localizedDescription)
            }
        } else {
            scanner.stopScanning()
        }
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onBarcode: (String) -> Void
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
                dataScanner.stopScanning()
                onBarcode(value)
                return
            }
        }
    }
}
#endif
