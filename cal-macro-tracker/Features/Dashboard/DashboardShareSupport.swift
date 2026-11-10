import SwiftUI

extension DashboardScreen {
    func dashboardToolbarTrailing() -> some ToolbarContent {
        ToolbarItem(placement: .appTopBarTrailing) {
            HStack(spacing: 0) {
                #if os(iOS)
                toolbarIcon("square.and.arrow.up", label: "Share daily summary") { isShareSheetPresented = true }
                #endif
                toolbarIcon("chart.xyaxis.line", label: "Open insights", action: onOpenInsights)
                toolbarIcon("calendar", label: "Open history", action: onOpenHistory)
                toolbarIcon("gearshape", label: "Open settings", action: onOpenSettings)
            }
            .foregroundStyle(.primary)
            .disabled(tutorial.isRunning)
        }
    }

    private func toolbarIcon(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .appTopBarIconStyle()
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
