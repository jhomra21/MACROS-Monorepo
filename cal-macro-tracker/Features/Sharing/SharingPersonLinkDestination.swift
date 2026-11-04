import SwiftUI

struct SharingPersonLinkDestination: View {
    @Environment(AppDayContext.self) private var dayContext
    @Environment(SharingSyncService.self) private var sharing
    let profileId: String

    var body: some View {
        Group {
            if !sharing.isDeviceSharingEnabled {
                ContentUnavailableView {
                    Label("Sharing is off", systemImage: "person.2.slash")
                } description: {
                    Text("Turn on sharing on this device to view shared macros.")
                } actions: {
                    Link("Open Sharing", destination: AppOpenRequest.sharing(inviteInput: nil).url)
                }
                .navigationTitle("Sharing")
                .inlineNavigationTitle()
            } else if sharing.hasReceivedDashboard {
                if let person = sharing.dashboard.people.first(where: { $0.profileId == profileId }) {
                    SharingPersonScreen(person: person)
                } else {
                    ContentUnavailableView(
                        "Person unavailable", systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("This person is no longer connected. Open Sharing to choose someone else.")
                    )
                    .navigationTitle("Sharing")
                    .inlineNavigationTitle()
                }
            } else if let error = sharing.dashboardErrorMessage {
                ContentUnavailableView {
                    Label("Couldn't load Sharing", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { sharing.startDashboardSubscription(for: dayContext.today) }
                }
            } else {
                ProgressView("Loading sharing…")
            }
        }
        .task(id: dayContext.today) {
            sharing.startDashboardSubscription(for: dayContext.today)
        }
    }
}
