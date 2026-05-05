#if os(iOS)
import SwiftUI
import UIKit

enum MacroRingColorPickerPresenter {
    static func present(for metric: MacroMetric, hex: Binding<String>) {
        var didChangeColor = false
        ColorPickerPresenter.present(
            initialColor: Color(hex: hex.wrappedValue) ?? MacroRingPalette.standard.color(for: metric)
        ) { selectedColor in
            guard let newHex = Color(selectedColor).hexString, hex.wrappedValue != newHex else { return }

            hex.wrappedValue = newHex
            didChangeColor = true
        } onFinish: {
            if didChangeColor {
                WidgetTimelineReloader.reloadMacroWidgets()
            }
        }
    }
}

private enum ColorPickerPresenter {
    private static var delegateAssociationKey = 0

    static func present(initialColor: Color, onChange: @escaping (UIColor) -> Void, onFinish: @escaping () -> Void) {
        guard let presenter = UIApplication.shared.activeTopViewController else { return }
        let picker = UIColorPickerViewController()
        picker.supportsAlpha = false
        picker.selectedColor = UIColor(initialColor)
        if let sheet = picker.sheetPresentationController {
            let compactColorPickerDetent = UISheetPresentationController.Detent.custom(
                identifier: .colorPickerCompact
            ) { context in
                min(context.maximumDetentValue * 0.72, 556)
            }
            sheet.detents = [compactColorPickerDetent, .large()]
            sheet.selectedDetentIdentifier = .colorPickerCompact
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }

        let delegate = ColorPickerDelegate(onChange: onChange, onFinish: onFinish)
        picker.delegate = delegate
        objc_setAssociatedObject(picker, &delegateAssociationKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        presenter.present(picker, animated: true)
    }
}

private final class ColorPickerDelegate: NSObject, UIColorPickerViewControllerDelegate {
    private let onChange: (UIColor) -> Void
    private let onFinish: () -> Void

    init(onChange: @escaping (UIColor) -> Void, onFinish: @escaping () -> Void) {
        self.onChange = onChange
        self.onFinish = onFinish
    }

    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        onChange(viewController.selectedColor)
    }

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        onFinish()
    }
}

private extension UIApplication {
    var activeTopViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow?
            .rootViewController?
            .topPresentedViewController
    }
}

private extension UIViewController {
    var topPresentedViewController: UIViewController {
        presentedViewController?.topPresentedViewController ?? self
    }
}

private extension UISheetPresentationController.Detent.Identifier {
    static let colorPickerCompact = Self("colorPickerCompact")
}
#endif
