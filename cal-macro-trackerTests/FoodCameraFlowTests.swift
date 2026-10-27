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
            XCTAssertEqual(flow.reduce(.sceneInactive), phase == .dismissed ? [] : [.stopScanning, .torchOff], "\(phase)")
            XCTAssertEqual(flow.phase, phase, "\(phase)")
        }
    }

    func testDismissalFromEveryPhaseStopsCancelsAndTurnsTorchOff() {
        for phase in FoodCameraFlow.Phase.allTestPhases {
            var flow = flow(in: phase)
            XCTAssertEqual(flow.reduce(.dismissed), phase == .dismissed ? [] : [.stopScanning, .cancelWork, .torchOff], "\(phase)")
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

    func testActiveLibraryCancellationRestartsScanning() {
        var flow = FoodCameraFlow()
        XCTAssertEqual(flow.reduce(.libraryOpened), [.stopScanning, .torchOff])
        XCTAssertEqual(flow.phase, .library)
        XCTAssertEqual(flow.reduce(.libraryCancelled), [.startScanning])
        XCTAssertEqual(flow.phase, .scanning)
    }

    func testLibraryOpenedBeforeBackgroundDoesNotResumeUntilActive() {
        var flow = FoodCameraFlow()
        XCTAssertEqual(flow.reduce(.libraryOpened), [.stopScanning, .torchOff])
        XCTAssertEqual(flow.phase, .library)
        XCTAssertEqual(flow.reduce(.sceneInactive), [.stopScanning, .torchOff])
        XCTAssertEqual(flow.phase, .library)
        XCTAssertEqual(flow.reduce(.libraryCancelled), [])
        XCTAssertEqual(flow.phase, .scanning)
        XCTAssertTrue(flow.isInactive)
        XCTAssertEqual(flow.reduce(.sceneActive), [.startScanning])
        XCTAssertEqual(flow.phase, .scanning)
    }

    func testLiveBarcodeIsIgnoredDuringOCRAndCapture() {
        for phase: FoodCameraFlow.Phase in [.readingLabel, .capturing] {
            var flow = flow(in: phase)
            XCTAssertEqual(flow.reduce(.barcodeRecognized("late")), [])
            XCTAssertEqual(flow.phase, phase)
        }
    }

    func testSecondShutterIsIgnoredDuringCapture() {
        var flow = flow(in: .capturing)
        XCTAssertEqual(flow.reduce(.shutterTapped), [])
        XCTAssertEqual(flow.phase, .capturing)
    }

    func testInactiveLookupCompletionKeepsResultWithoutRestarting() {
        var flow = flow(in: .lookingUp)
        XCTAssertEqual(flow.reduce(.sceneInactive), [.stopScanning, .torchOff])
        XCTAssertEqual(flow.phase, .lookingUp)
        XCTAssertEqual(flow.reduce(.lookupFinished), [])
        XCTAssertEqual(flow.phase, .showingBarcode)
        XCTAssertEqual(flow.reduce(.sceneActive), [])
        XCTAssertEqual(flow.phase, .showingBarcode)
    }

    func testScanAgainStartsOnlyWhenActive() {
        var active = barcodeResultFlow()
        XCTAssertEqual(active.reduce(.scanAgain), [.cancelWork, .torchOff, .startScanning])
        XCTAssertEqual(active.phase, .scanning)
        var inactive = barcodeResultFlow()
        XCTAssertEqual(inactive.reduce(.sceneInactive), [.stopScanning, .torchOff])
        XCTAssertEqual(inactive.phase, .showingBarcode)
        XCTAssertEqual(inactive.reduce(.scanAgain), [.cancelWork, .torchOff, .stopScanning])
        XCTAssertEqual(inactive.phase, .scanning)
    }

    func testOCRFailureClearsBarcodeRecoveryForLabelManualEntry() {
        var flow = flow(in: .readingLabel)
        let barcodeDestination = BarcodeManualFallbackFactory.destination(for: "123")
        XCTAssertEqual(
            flow.reduce(.recoveryDestinationChanged(barcodeDestination)),
            [.recoveryDestination(barcodeDestination)]
        )
        XCTAssertEqual(flow.phase, .readingLabel)
        XCTAssertEqual(flow.reduce(.ocrFailed), [.recoveryDestination(nil)])
        XCTAssertEqual(flow.phase, .recovering)
    }

    func testDismissedFlowRejectsEventsAndContent() {
        var flow = flow(in: .dismissed)
        let events: [FoodCameraFlow.Event] = [
            .barcodeRecognized("123"), .barcodeFromImage("123"), .shutterTapped,
            .libraryOpened, .libraryCancelled, .imagePicked, .lookupFinished,
            .lookupFailed("123"), .scannerFailed, .importFailed, .captureFailed,
            .ocrFinished, .ocrFailed, .photoCaptured, .imageBarcodeMissing,
            .logTapped, .logFinished, .scanAgain, .servingsChanged(2),
            .sceneInactive, .sceneActive, .navigationAway,
            .contentChanged(.message("late")), .recoveryDestinationChanged(nil)
        ]
        for event in events {
            XCTAssertEqual(flow.reduce(event), [])
            XCTAssertEqual(flow.phase, .dismissed)
        }
    }

    func testInvalidQuantityIsRejected() {
        var flow = barcodeResultFlow()
        for amount in [0, -1, Double.nan, .infinity] {
            XCTAssertEqual(flow.reduce(.servingsChanged(amount)), [])
            XCTAssertEqual(flow.phase, .showingBarcode)
            XCTAssertEqual(flow.servings, 1)
        }
    }

    func testValidationFailureFinishesSavingAndUnblocksResult() {
        var flow = barcodeResultFlow()
        XCTAssertEqual(flow.reduce(.logTapped), [.log(servings: 1)])
        XCTAssertEqual(flow.phase, .showingBarcode)
        XCTAssertTrue(flow.isSaving)
        XCTAssertEqual(flow.reduce(.logFinished), [])
        XCTAssertEqual(flow.phase, .showingBarcode)
        XCTAssertFalse(flow.isSaving)
    }

    func testRepeatedDismissalHasNoEffects() {
        var flow = FoodCameraFlow()
        XCTAssertEqual(flow.reduce(.dismissed), [.stopScanning, .cancelWork, .torchOff])
        XCTAssertEqual(flow.phase, .dismissed)
        XCTAssertEqual(flow.reduce(.dismissed), [])
        XCTAssertEqual(flow.phase, .dismissed)
    }

    func testTorchToggleIsOwnedByScanningPhase() {
        var scanning = FoodCameraFlow()
        XCTAssertEqual(scanning.reduce(.torchToggled), [.torchOn])
        XCTAssertEqual(scanning.phase, .scanning)
        XCTAssertEqual(scanning.reduce(.torchToggled), [.torchOff])
        XCTAssertEqual(scanning.phase, .scanning)
        for phase in FoodCameraFlow.Phase.allTestPhases where phase != .scanning {
            var other = flow(in: phase)
            XCTAssertEqual(other.reduce(.torchToggled), [])
            XCTAssertEqual(other.phase, phase)
        }
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
            .dismissed
        ]
    }
}
