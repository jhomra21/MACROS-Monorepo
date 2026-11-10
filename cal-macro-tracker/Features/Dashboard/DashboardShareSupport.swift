import SwiftUI

extension DashboardScreen {
    func dashboardToolbarTrailing() -> some ToolbarContent {
        ToolbarItem(placement: .appTopBarTrailing) {
            HStack(spacing: 0) {
                #if os(iOS)
                shareMenu
                #endif
                toolbarIcon("chart.xyaxis.line", label: "Open insights", action: onOpenInsights)
                toolbarIcon("calendar", label: "Open history", action: onOpenHistory)
                toolbarIcon("gearshape", label: "Open settings", action: onOpenSettings)
            }
            .foregroundStyle(.primary)
            .disabled(tutorial.isRunning)
        }
    }

    #if os(iOS)
    private var sharesWithPeople: Bool {
        entitlements.hasPro && sharingSyncService.isDeviceSharingEnabled
    }

    /// Only a Pro device with sharing on knows a count; setup, offline and loading show the plain description.
    private var liveSharingSubtitle: String {
        guard sharesWithPeople, sharingSyncService.hasReceivedDashboard else {
            return "Your macros with people you choose"
        }
        return switch sharingSyncService.dashboard.people.count {
        case 0: "Your macros with people you choose"
        case 1: "With 1 person"
        case let count: "With \(count) people"
        }
    }

    private var shareMenu: some View {
        Menu {
            Button(action: { isShareSheetPresented = true }) {
                Text("Post an image")
                Text("Your rings and macros for social media")
                Image(systemName: "photo")
            }
            Button(action: sharesWithPeople ? onOpenSharing : onOpenSharingSetup) {
                Text("Live sharing")
                Text(liveSharingSubtitle)
                Image(systemName: "person.2")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .appTopBarIconStyle()
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Share daily summary")
    }
    #endif

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
