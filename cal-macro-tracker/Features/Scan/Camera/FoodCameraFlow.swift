import Foundation

struct FoodCameraFlow: Sendable {
    enum Phase: Equatable, Sendable {
        case scanning
        case lookingUp
        case capturing
        case readingLabel
        case library
        case showingBarcode
        case showingLabel
        case recovering
        case dismissed
    }

    enum Event {
        case barcodeRecognized(String)
        case barcodeFromImage(String)
        case shutterTapped
        case libraryOpened
        case libraryCancelled
        case imagePicked
        case lookupFinished
        case lookupFailed(String)
        case scannerFailed
        case importFailed
        case captureFailed
        case ocrFinished
        case ocrFailed
        case photoCaptured
        case imageBarcodeMissing
        case logTapped
        case logFinished
        case scanAgain
        case servingsChanged(Double)
        case sceneInactive
        case sceneActive
        case navigationAway
        case dismissed
        case contentChanged(FoodCameraResultPanel.Content)
        case recoveryDestinationChanged(BarcodeScanLogFoodDestination?)
    }

    enum Effect: Equatable {
        case startScanning
        case stopScanning
        case torchOff
        case cancelWork
        case lookup(barcode: String)
        case scanImage
        case capturePhoto
        case readLabel
        case log(servings: Double)
        case content(FoodCameraResultPanel.Content)
        case recoveryDestination(BarcodeScanLogFoodDestination?)
    }

    private(set) var phase: Phase = .scanning
    private(set) var isInactive = false
    private(set) var isSaving = false
    private(set) var servings = 1.0
    private var libraryPausedScanning = false
    private var phaseBeforeLibrary: Phase = .scanning

    mutating func reduce(_ event: Event) -> [Effect] {
        switch event {
        case .contentChanged(let content) where phase != .dismissed:
            return [.content(content)]
        case .recoveryDestinationChanged(let destination) where phase != .dismissed:
            return [.recoveryDestination(destination)]
        case .contentChanged, .recoveryDestinationChanged:
            return []
        case let .barcodeRecognized(barcode) where phase == .scanning && isInactive == false:
            phase = .lookingUp
            return [.stopScanning, .torchOff, .lookup(barcode: barcode)]
        case let .barcodeFromImage(barcode) where phase == .readingLabel:
            phase = .lookingUp
            return [.stopScanning, .torchOff, .lookup(barcode: barcode)]
        case .barcodeFromImage:
            return []
        case .barcodeRecognized:
            return []
        case .shutterTapped where isIdleCapturePhase && isInactive == false:
            phase = .capturing
            return [.capturePhoto]
        case .shutterTapped:
            return []
        case .libraryOpened where phase == .scanning || phase == .showingBarcode || phase == .showingLabel || phase == .recovering:
            libraryPausedScanning = phase == .scanning && isInactive == false
            phaseBeforeLibrary = phase
            phase = .library
            return [.stopScanning, .torchOff]
        case .libraryOpened:
            return []
        case .libraryCancelled where phase == .library:
            phase = libraryPausedScanning && isInactive == false ? .scanning : phaseBeforeLibrary
            let shouldResume = libraryPausedScanning && phase == .scanning
            libraryPausedScanning = false
            return shouldResume ? [.startScanning] : []
        case .libraryCancelled:
            return []
        case .imagePicked where phase == .library || phase == .capturing || phase == .scanning:
            phase = .readingLabel
            servings = 1
            return [.scanImage]
        case .imagePicked:
            return []
        case .lookupFinished where phase == .lookingUp:
            phase = .showingBarcode
            return []
        case .lookupFinished:
            return []
        case .lookupFailed where phase == .lookingUp:
            phase = .recovering
            return []
        case .lookupFailed:
            return []
        case .captureFailed where phase == .capturing:
            phase = .recovering
            return []
        case .captureFailed:
            return []
        case .photoCaptured where phase == .capturing:
            phase = .readingLabel
            return [.stopScanning, .torchOff, .readLabel]
        case .photoCaptured:
            return []
        case .imageBarcodeMissing where phase == .readingLabel:
            return [.readLabel]
        case .imageBarcodeMissing:
            return []
        case .ocrFinished where phase == .readingLabel || phase == .capturing:
            phase = .showingLabel
            return []
        case .ocrFinished:
            return []
        case .ocrFailed where phase == .readingLabel || phase == .capturing:
            phase = .recovering
            return []
        case .ocrFailed:
            return []
        case .scannerFailed where phase != .dismissed:
            phase = .recovering
            return [.stopScanning, .torchOff]
        case .scannerFailed:
            return []
        case .importFailed where phase == .readingLabel || phase == .library:
            phase = .recovering
            return [.torchOff]
        case .importFailed:
            return []
        case .logTapped where phase == .showingBarcode && isSaving == false:
            isSaving = true
            return [.log(servings: servings)]
        case .logTapped:
            return []
        case .logFinished where isSaving:
            isSaving = false
            return []
        case .logFinished:
            return []
        case .servingsChanged(let amount) where phase == .showingBarcode && amount.isFinite && amount > 0:
            servings = amount
            return []
        case .servingsChanged:
            return []
        case .scanAgain where phase != .dismissed:
            phase = .scanning
            isSaving = false
            servings = 1
            return [.cancelWork, .torchOff, isInactive ? .stopScanning : .startScanning]
        case .scanAgain:
            return []
        case .sceneInactive:
            isInactive = true
            return [.stopScanning, .torchOff]
        case .sceneActive:
            isInactive = false
            return phase == .scanning ? [.startScanning] : []
        case .navigationAway:
            isInactive = true
            return [.stopScanning, .cancelWork, .torchOff]
        case .dismissed:
            phase = .dismissed
            isSaving = false
            return [.stopScanning, .cancelWork, .torchOff]
        }
    }

    private var isIdleCapturePhase: Bool {
        phase == .scanning || phase == .recovering || phase == .showingBarcode || phase == .showingLabel
    }

}
