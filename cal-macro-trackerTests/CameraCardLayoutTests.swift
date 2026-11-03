import SwiftUI
import UIKit
import XCTest
@testable import cal_macro_tracker

@MainActor
final class CameraCardLayoutTests: XCTestCase {
    // Failure cases: fractional macro widths, singular/total serving descriptions,
    // a two-line name, editable label names, narrow phones, and accessibility text.
    func testServingChangesKeepBarcodeAndLabelCardHeight() throws {
        var measurements = ["kind,width,type,servings,height"]
        for width in [390.0, 402, 440] {
            for size in [DynamicTypeSize.large, .accessibility3] {
                for isLabel in [false, true] {
                    let heights = (1...80).map { step in
                        let amount = Double(step) / 4
                        let height = height(width: width, size: size, isLabel: isLabel, servings: amount)
                        measurements.append("\(isLabel ? "label" : "barcode"),\(width),\(size),\(amount),\(height)")
                        return height
                    }
                    XCTAssertEqual(
                        heights.min()!, heights.max()!, accuracy: 0.5,
                        "width=\(width), size=\(size), label=\(isLabel), heights=\(Set(heights))"
                    )
                }
            }
        }
        try save(Data((measurements.joined(separator: "\n") + "\n").utf8), name: "heights.csv")
    }

    private func height(width: CGFloat, size: DynamicTypeSize, isLabel: Bool, servings: Double) -> CGFloat {
        var draft = FoodDraft()
        draft.name = "Fajita Flour Tortillas"
        draft.brand = "Guerrero"
        draft.servingDescription = "1 tortilla (37 g)"
        draft.gramsPerServing = 37
        draft.caloriesPerServing = 160
        draft.proteinPerServing = 2
        draft.carbsPerServing = 17
        draft.fatPerServing = 5
        let content: FoodCameraResultPanel.Content =
            isLabel
            ? .label(draft, notes: [], missingNutrients: [], servings: servings, logged: false)
            : .barcode(draft, servings: servings, logged: false)
        let view = FoodCameraResultPanel(
            content: content, goals: .default, onChangeServings: { _ in },
            onChangeName: { _ in }, onLog: {}, onDetails: {}, onReview: {},
            onManual: {}, onSearch: {}
        )
        .environment(\.dynamicTypeSize, size)
        let host = UIHostingController(rootView: view)
        let height = host.sizeThatFits(in: CGSize(width: width - 32, height: .greatestFiniteMagnitude)).height
        return height
    }

    private func save(_ data: Data, name: String) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("camera-card-layout")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: folder.appendingPathComponent(name))
        print("CAMERA_CARD_EVIDENCE \(folder.path)/\(name)")
    }
}
