import XCTest
@testable import cal_macro_tracker

final class FoodCameraFlowTests: XCTestCase {
    func testDuplicateBarcodeRecognitionDuringLookupIsIgnored() {
        var flow = FoodCameraFlow()
        _ = flow.reduce(.barcodeRecognized("first"))

        XCTAssertTrue(flow.reduce(.barcodeRecognized("second")).isEmpty)
        XCTAssertEqual(flow.phase, .lookingUp)
    }

    func testBarcodeRecognitionDuringLabelProcessingIsIgnored() {
        var flow = FoodCameraFlow()
        _ = flow.reduce(.libraryOpened)
        _ = flow.reduce(.imagePicked)

        XCTAssertTrue(flow.reduce(.barcodeRecognized("123")).isEmpty)
        XCTAssertEqual(flow.phase, .readingLabel)

        var imageFlow = FoodCameraFlow()
        _ = imageFlow.reduce(.libraryOpened)
        _ = imageFlow.reduce(.imagePicked)
        XCTAssertTrue(imageFlow.reduce(.barcodeFromImage("123")).contains(.lookup(barcode: "123")))
        XCTAssertEqual(imageFlow.phase, .lookingUp)
    }

    func testSecondShutterTapDuringCaptureIsIgnored() {
        var flow = FoodCameraFlow()
        _ = flow.reduce(.shutterTapped)

        XCTAssertTrue(flow.reduce(.shutterTapped).isEmpty)
        XCTAssertEqual(flow.phase, .capturing)
    }

    func testLibraryPausesAndOnlyResumesAnIdleScanningSession() {
        var scanningFlow = FoodCameraFlow()
        _ = scanningFlow.reduce(.libraryOpened)
        XCTAssertEqual(scanningFlow.phase, .library)
        XCTAssertTrue(scanningFlow.reduce(.libraryCancelled).contains(.startScanning))

        var lookupFlow = FoodCameraFlow()
        _ = lookupFlow.reduce(.barcodeRecognized("123"))
        _ = lookupFlow.reduce(.libraryOpened)
        XCTAssertTrue(lookupFlow.reduce(.libraryCancelled).isEmpty)
        XCTAssertEqual(lookupFlow.phase, .lookingUp)
    }

    func testSceneInactiveAlwaysStopsCaptureIncludingDuringShutterCapture() {
        var flow = FoodCameraFlow()
        _ = flow.reduce(.shutterTapped)

        let effects = flow.reduce(.sceneInactive)

        XCTAssertTrue(effects.contains(.stopScanning))
        XCTAssertTrue(flow.isInactive)
    }

    func testSceneActiveResumesOnlyScanningWithoutPendingResult() {
        var scanningFlow = FoodCameraFlow()
        _ = scanningFlow.reduce(.sceneInactive)
        XCTAssertTrue(scanningFlow.reduce(.sceneActive).contains(.startScanning))

        var resultFlow = FoodCameraFlow()
        _ = resultFlow.reduce(.barcodeRecognized("123"))
        _ = resultFlow.reduce(.lookupFinished)
        _ = resultFlow.reduce(.sceneInactive)
        XCTAssertFalse(resultFlow.reduce(.sceneActive).contains(.startScanning))
    }

    func testDismissalCancelsInFlightWork() {
        var flow = FoodCameraFlow()
        _ = flow.reduce(.barcodeRecognized("123"))

        let effects = flow.reduce(.dismissed)

        XCTAssertTrue(effects.contains(.cancelWork))
        XCTAssertEqual(flow.phase, .dismissed)
    }

    func testNewOperationClearsBarcodeRecoveryMetadata() {
        var flow = FoodCameraFlow()
        _ = flow.reduce(.barcodeRecognized("first"))
        _ = flow.reduce(.lookupFailed("first"))
        XCTAssertEqual(flow.recoveryBarcode, "first")

        _ = flow.reduce(.scanAgain)
        _ = flow.reduce(.libraryOpened)
        _ = flow.reduce(.imagePicked)
        _ = flow.reduce(.ocrFailed)

        XCTAssertNil(flow.recoveryBarcode)
    }

    func testSavePendingDisablesAnotherLog() {
        var flow = FoodCameraFlow()
        _ = flow.reduce(.barcodeRecognized("123"))
        _ = flow.reduce(.lookupFinished)
        _ = flow.reduce(.logTapped)

        XCTAssertTrue(flow.isSaving)
        XCTAssertTrue(flow.reduce(.logTapped).isEmpty)
    }

    func testServingsAmountFlowsIntoLoggedQuantity() {
        var flow = FoodCameraFlow()
        _ = flow.reduce(.barcodeRecognized("123"))
        _ = flow.reduce(.lookupFinished)
        _ = flow.reduce(.servingsChanged(2))

        XCTAssertEqual(flow.servings, 2)
        XCTAssertTrue(flow.reduce(.logTapped).contains(.log(servings: 2)))
    }
}
