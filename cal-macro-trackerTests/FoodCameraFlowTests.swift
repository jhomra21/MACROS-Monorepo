import XCTest
@testable import cal_macro_tracker

final class FoodCameraFlowTests: XCTestCase {
    func testBarcodeRecognitionStartsLookupInExactOrder() {
        var flow = FoodCameraFlow()
        XCTAssertEqual(
            flow.reduce(.barcodeRecognized("first")),
            [.stopScanning, .torchOff, .lookup(barcode: "first")]
        )
        XCTAssertEqual(flow.phase, .lookingUp)
        XCTAssertEqual(flow.reduce(.barcodeRecognized("second")), [])
        XCTAssertEqual(flow.phase, .lookingUp)
    }

    func testBarcodeFromImageAndOCRCanCompleteWhileInactive() {
        var flow = FoodCameraFlow()
        XCTAssertEqual(flow.reduce(.libraryOpened), [.stopScanning, .torchOff])
        XCTAssertEqual(flow.phase, .library)
        XCTAssertEqual(flow.reduce(.imagePicked), [.scanImage])
        XCTAssertEqual(flow.phase, .readingLabel)
        XCTAssertEqual(flow.reduce(.navigationAway), [.stopScanning, .cancelWork, .torchOff])
        XCTAssertEqual(flow.phase, .readingLabel)
        XCTAssertEqual(
            flow.reduce(.barcodeFromImage("123")),
            [.stopScanning, .torchOff, .lookup(barcode: "123")]
        )
        XCTAssertEqual(flow.phase, .lookingUp)

        var ocrFlow = FoodCameraFlow()
        XCTAssertEqual(ocrFlow.reduce(.libraryOpened), [.stopScanning, .torchOff])
        XCTAssertEqual(ocrFlow.phase, .library)
        XCTAssertEqual(ocrFlow.reduce(.imagePicked), [.scanImage])
        XCTAssertEqual(ocrFlow.phase, .readingLabel)
        XCTAssertEqual(ocrFlow.reduce(.sceneInactive), [.stopScanning, .torchOff])
        XCTAssertEqual(ocrFlow.phase, .readingLabel)
        XCTAssertEqual(ocrFlow.reduce(.ocrFinished), [])
        XCTAssertEqual(ocrFlow.phase, .showingLabel)
        XCTAssertEqual(ocrFlow.reduce(.sceneActive), [])
        XCTAssertEqual(ocrFlow.phase, .showingLabel)
    }

    func testShutterCaptureOrderAndRecoveryShutter() {
        var flow = FoodCameraFlow()
        XCTAssertEqual(flow.reduce(.shutterTapped), [.capturePhoto])
        XCTAssertEqual(flow.phase, .capturing)
        XCTAssertEqual(flow.reduce(.photoCaptured), [.stopScanning, .torchOff, .readLabel])
        XCTAssertEqual(flow.phase, .readingLabel)

        var recovering = FoodCameraFlow()
        XCTAssertEqual(
            recovering.reduce(.barcodeRecognized("123")),
            [.stopScanning, .torchOff, .lookup(barcode: "123")]
        )
        XCTAssertEqual(recovering.phase, .lookingUp)
        XCTAssertEqual(recovering.reduce(.lookupFailed("123")), [])
        XCTAssertEqual(recovering.phase, .recovering)
        XCTAssertEqual(recovering.reduce(.shutterTapped), [.capturePhoto])
        XCTAssertEqual(recovering.phase, .capturing)
    }

    func testLibraryReplacementResetsServingsButCancellationPreservesThem() {
        var replacement = barcodeResultFlow()
        XCTAssertEqual(replacement.reduce(.servingsChanged(2)), [])
        XCTAssertEqual(replacement.phase, .showingBarcode)
        XCTAssertEqual(replacement.servings, 2)
        XCTAssertEqual(replacement.reduce(.libraryOpened), [.stopScanning, .torchOff])
        XCTAssertEqual(replacement.phase, .library)
        XCTAssertEqual(replacement.servings, 2)
        XCTAssertEqual(replacement.reduce(.imagePicked), [.scanImage])
        XCTAssertEqual(replacement.phase, .readingLabel)
        XCTAssertEqual(replacement.servings, 1)

        var cancelled = barcodeResultFlow()
        XCTAssertEqual(cancelled.reduce(.servingsChanged(2)), [])
        XCTAssertEqual(cancelled.phase, .showingBarcode)
        XCTAssertEqual(cancelled.reduce(.libraryOpened), [.stopScanning, .torchOff])
        XCTAssertEqual(cancelled.phase, .library)
        XCTAssertEqual(cancelled.reduce(.libraryCancelled), [])
        XCTAssertEqual(cancelled.phase, .showingBarcode)
        XCTAssertEqual(cancelled.servings, 2)
    }

    func testLibraryCancellationWhileInactiveDoesNotRestartScanner() {
        var flow = FoodCameraFlow()
        XCTAssertEqual(flow.reduce(.sceneInactive), [.stopScanning, .torchOff])
        XCTAssertEqual(flow.phase, .scanning)
        XCTAssertEqual(flow.reduce(.libraryOpened), [.stopScanning, .torchOff])
        XCTAssertEqual(flow.phase, .library)
        XCTAssertEqual(flow.reduce(.libraryCancelled), [])
        XCTAssertEqual(flow.phase, .scanning)
    }

    func testSceneInactiveStopsCaptureAndTorchFromEveryPhase() {
        for phase in FoodCameraFlow.Phase.allTestPhases {
            var flow = flow(in: phase)
            XCTAssertEqual(flow.reduce(.sceneInactive), [.stopScanning, .torchOff], "\(phase)")
            XCTAssertEqual(flow.phase, phase, "\(phase)")
        }
    }

    func testDismissalFromEveryPhaseStopsCancelsAndTurnsTorchOff() {
        for phase in FoodCameraFlow.Phase.allTestPhases {
            var flow = flow(in: phase)
            XCTAssertEqual(flow.reduce(.dismissed), [.stopScanning, .cancelWork, .torchOff], "\(phase)")
            XCTAssertEqual(flow.phase, .dismissed, "\(phase)")
        }
    }

    func testNavigationAwayAndBackPreservesResultPhase() {
        var flow = barcodeResultFlow()
        XCTAssertEqual(flow.reduce(.navigationAway), [.stopScanning, .cancelWork, .torchOff])
        XCTAssertEqual(flow.phase, .showingBarcode)
        XCTAssertEqual(flow.reduce(.sceneActive), [])
        XCTAssertEqual(flow.phase, .showingBarcode)
    }

    func testScannerAndImageImportFailuresEnterRecovery() {
        var scanner = FoodCameraFlow()
        XCTAssertEqual(scanner.reduce(.scannerFailed), [.stopScanning, .torchOff])
        XCTAssertEqual(scanner.phase, .recovering)

        var imageImport = FoodCameraFlow()
        XCTAssertEqual(imageImport.reduce(.libraryOpened), [.stopScanning, .torchOff])
        XCTAssertEqual(imageImport.phase, .library)
        XCTAssertEqual(imageImport.reduce(.importFailed), [.torchOff])
        XCTAssertEqual(imageImport.phase, .recovering)

        var capture = FoodCameraFlow()
        XCTAssertEqual(capture.reduce(.shutterTapped), [.capturePhoto])
        XCTAssertEqual(capture.phase, .capturing)
        XCTAssertEqual(capture.reduce(.sceneInactive), [.stopScanning, .torchOff])
        XCTAssertEqual(capture.phase, .capturing)
        XCTAssertEqual(capture.reduce(.captureFailed), [])
        XCTAssertEqual(capture.phase, .recovering)
    }

    func testSavingAndQuantityTransitionsHaveExactEffects() {
        var flow = barcodeResultFlow()
        XCTAssertEqual(flow.reduce(.servingsChanged(2)), [])
        XCTAssertEqual(flow.phase, .showingBarcode)
        XCTAssertEqual(flow.servings, 2)
        XCTAssertEqual(flow.reduce(.logTapped), [.log(servings: 2)])
        XCTAssertEqual(flow.phase, .showingBarcode)
        XCTAssertTrue(flow.isSaving)
        XCTAssertEqual(flow.reduce(.logTapped), [])
        XCTAssertEqual(flow.phase, .showingBarcode)
        XCTAssertEqual(flow.reduce(.logFinished), [])
        XCTAssertEqual(flow.phase, .showingBarcode)
        XCTAssertFalse(flow.isSaving)
    }

    private func barcodeResultFlow() -> FoodCameraFlow {
        var flow = FoodCameraFlow()
        _ = flow.reduce(.barcodeRecognized("123"))
        _ = flow.reduce(.lookupFinished)
        return flow
    }

    private func flow(in phase: FoodCameraFlow.Phase) -> FoodCameraFlow {
        var flow = FoodCameraFlow()
        switch phase {
        case .scanning:
            break
        case .lookingUp:
            _ = flow.reduce(.barcodeRecognized("123"))
        case .capturing:
            _ = flow.reduce(.shutterTapped)
        case .readingLabel:
            _ = flow.reduce(.libraryOpened)
            _ = flow.reduce(.imagePicked)
        case .library:
            _ = flow.reduce(.libraryOpened)
        case .showingBarcode:
            flow = barcodeResultFlow()
        case .showingLabel:
            _ = flow.reduce(.libraryOpened)
            _ = flow.reduce(.imagePicked)
            _ = flow.reduce(.ocrFinished)
        case .recovering:
            _ = flow.reduce(.barcodeRecognized("123"))
            _ = flow.reduce(.lookupFailed("123"))
        case .dismissed:
            _ = flow.reduce(.dismissed)
        }
        return flow
    }
}

private extension FoodCameraFlow.Phase {
    static var allTestPhases: [Self] {
        [
            .scanning,
            .lookingUp,
            .capturing,
            .readingLabel,
            .library,
            .showingBarcode,
            .showingLabel,
            .recovering,
            .dismissed,
        ]
    }
}
