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

    enum Event: Sendable {
        case barcodeRecognized(String)
        case barcodeFromImage(String)
        case shutterTapped
        case libraryOpened
        case libraryCancelled
        case imagePicked
        case lookupFinished
        case lookupFailed(String)
        case captureFailed
        case ocrFinished
        case ocrFailed
        case logTapped
        case logFinished
        case scanAgain
        case servingsChanged(Double)
        case sceneInactive
        case sceneActive
        case dismissed
    }

    enum Effect: Equatable, Sendable {
        case startScanning
        case stopScanning
        case cancelWork
        case lookup(barcode: String)
        case scanImage
        case capturePhoto
        case readLabel
        case log(servings: Double)
        case openEditor(barcode: String?)
    }

    private(set) var phase: Phase = .scanning
    private(set) var isInactive = false
    private(set) var isSaving = false
    private(set) var servings = 1.0
    private(set) var recoveryBarcode: String?
    private var libraryPausedScanning = false
    private var phaseBeforeLibrary: Phase = .scanning

    mutating func reduce(_ event: Event) -> [Effect] {
        switch event {
        case let .barcodeRecognized(barcode) where phase == .scanning && isInactive == false:
            phase = .lookingUp
            recoveryBarcode = nil
            return [.stopScanning, .lookup(barcode: barcode)]
        case let .barcodeFromImage(barcode) where phase == .readingLabel && isInactive == false:
            phase = .lookingUp
            recoveryBarcode = nil
            return [.stopScanning, .lookup(barcode: barcode)]
        case .barcodeFromImage:
            return []
        case .barcodeRecognized:
            return []
        case .shutterTapped where phase == .scanning && isInactive == false:
            phase = .capturing
            recoveryBarcode = nil
            return [.stopScanning, .capturePhoto]
        case .shutterTapped:
            return []
        case .libraryOpened where phase == .scanning || phase == .showingBarcode || phase == .showingLabel || phase == .recovering:
            libraryPausedScanning = phase == .scanning && isInactive == false
            phaseBeforeLibrary = phase
            phase = .library
            recoveryBarcode = nil
            return [.stopScanning]
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
            recoveryBarcode = nil
            return [.scanImage]
        case .imagePicked:
            return []
        case .lookupFinished where phase == .lookingUp:
            phase = .showingBarcode
            return []
        case .lookupFinished:
            return []
        case let .lookupFailed(barcode) where phase == .lookingUp:
            phase = .recovering
            recoveryBarcode = barcode
            return []
        case .lookupFailed:
            return []
        case .captureFailed where phase == .capturing:
            phase = .recovering
            return []
        case .captureFailed:
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
            recoveryBarcode = nil
            isSaving = false
            servings = 1
            return [.cancelWork, isInactive ? .stopScanning : .startScanning]
        case .scanAgain:
            return []
        case .sceneInactive:
            isInactive = true
            return [.stopScanning]
        case .sceneActive:
            isInactive = false
            return phase == .scanning ? [.startScanning] : []
        case .dismissed:
            phase = .dismissed
            isSaving = false
            return [.stopScanning, .cancelWork]
        }
    }

}
