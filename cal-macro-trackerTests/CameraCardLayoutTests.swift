import SwiftUI
import UIKit
import XCTest
@testable import cal_macro_tracker

@MainActor
final class CameraCardLayoutTests: XCTestCase {
    func testSharedRowVisualFixtures() {
        for size in [DynamicTypeSize.large, .accessibility3] {
            for subtitle in [nil, "1.75 servings • 12:00 PM"] as [String?] {
                let view = FoodNutritionRow(
                    name: "Fajita Flour Tortillas with Roasted Vegetables",
                    subtitle: subtitle, calories: 280, protein: 3.5, carbs: 29.8, fat: 8.8,
                    isStacked: size.isAccessibilitySize
                )
                .padding(.horizontal, 16)
                .environment(\.dynamicTypeSize, size)
                render(view, width: 390, name: "\(subtitle == nil ? "add-food" : "dashboard")-\(size).png")
            }
        }
    }

    // Failure cases: fractional macro widths, singular/total serving descriptions,
    // a two-line name, editable label names, narrow phones, and accessibility text.
    func testServingChangesKeepBarcodeAndLabelCardHeight() {
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
        save(Data((measurements.joined(separator: "\n") + "\n").utf8), name: "heights.csv")
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

    private func render(_ view: some View, width: CGFloat, name: String) {
        let renderer = ImageRenderer(
            content: view.environment(\.colorScheme, .dark).frame(width: width).background(.black)
        )
        renderer.scale = 2
        save(renderer.uiImage!.pngData()!, name: name)
    }

    private func save(_ data: Data, name: String) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("camera-card-layout")
        try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try! data.write(to: folder.appendingPathComponent(name))
        print("CAMERA_CARD_EVIDENCE \(folder.path)/\(name)")
    }
}
