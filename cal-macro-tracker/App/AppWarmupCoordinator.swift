import SwiftUI
#if os(iOS)
import UIKit
#endif

@MainActor
enum AppWarmupCoordinator {
    private static let firstRenderDelay: Duration = .milliseconds(350)
    private static var hasStarted = false

    static func warmUpAfterFirstRender() async {
        #if os(iOS)
        guard hasStarted == false else { return }
        hasStarted = true

        await Task.yield()
        try? await Task.sleep(for: firstRenderDelay)
        guard Task.isCancelled == false else { return }

        DailyShareImageExporter.warmUpRenderingPipeline(colorScheme: .light)
        warmUpShareController()
        #endif
    }

    #if os(iOS)
    private static func warmUpShareController() {
        let item = DashboardShareImageItemSource(image: warmUpImage(), title: "")
        let controller = UIActivityViewController(
            activityItems: [item],
            applicationActivities: nil
        )
        // Preload the system share view so LaunchServices setup does not run on the first user tap.
        _ = controller.view
    }

    private static func warmUpImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }
    #endif
}
