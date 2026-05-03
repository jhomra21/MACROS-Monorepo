struct NutritionLabelRecognizedText {
    let lines: [String]
}

#if os(iOS)
import UIKit
import Vision

struct NutritionLabelTextRecognizer {
    private let rowTolerance: CGFloat = 0.02

    func recognizeText(in image: UIImage) async throws -> NutritionLabelRecognizedText {
        let image = SendableScanImage(value: image)
        let rowTolerance = rowTolerance
        return try await Task.detached(priority: .userInitiated) {
            try recognizeTextSync(in: image.value, rowTolerance: rowTolerance)
        }.value
    }
}

private struct NutritionLabelRecognizedLine {
    let text: String
    let topEdge: CGFloat
    let leadingEdge: CGFloat
}

nonisolated private func recognizeTextSync(in image: UIImage, rowTolerance: CGFloat) throws -> NutritionLabelRecognizedText {
    let visionImage = try ScanImageLoading.makeVisionImage(from: image)
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false

    let handler = VNImageRequestHandler(cgImage: visionImage.cgImage, orientation: visionImage.orientation)
    try handler.perform([request])

    let lines = orderedLines(from: request.results ?? [], rowTolerance: rowTolerance)

    return NutritionLabelRecognizedText(lines: lines)
}

nonisolated private func orderedLines(from observations: [VNRecognizedTextObservation], rowTolerance: CGFloat) -> [String] {
    observations
        .compactMap(recognizedLine(from:))
        .sorted { areInReadingOrder($0, $1, rowTolerance: rowTolerance) }
        .map(\.text)
}

nonisolated private func recognizedLine(from observation: VNRecognizedTextObservation) -> NutritionLabelRecognizedLine? {
    guard let text = observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines),
        text.isEmpty == false
    else {
        return nil
    }

    return NutritionLabelRecognizedLine(
        text: text,
        topEdge: observation.boundingBox.maxY,
        leadingEdge: observation.boundingBox.minX
    )
}

nonisolated private func areInReadingOrder(
    _ lhs: NutritionLabelRecognizedLine,
    _ rhs: NutritionLabelRecognizedLine,
    rowTolerance: CGFloat
) -> Bool {
    if abs(lhs.topEdge - rhs.topEdge) > rowTolerance {
        return lhs.topEdge > rhs.topEdge
    }

    return lhs.leadingEdge < rhs.leadingEdge
}
#else
import Foundation

struct NutritionLabelTextRecognizer {
    func recognizeText(in imageData: Data) async throws -> NutritionLabelRecognizedText {
        throw NSError(
            domain: "NutritionLabelTextRecognizer", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Nutrition label text recognition is only available on iPhone builds."])
    }
}
#endif
