import Combine

@MainActor
struct SharingDashboardFeed {
    private let remote: any SharingRemote

    init(remote: any SharingRemote) {
        self.remote = remote
    }

    func dashboard(for day: CalendarDay) -> AnyPublisher<SharingDashboard, Error> {
        remote.dashboard(for: day)
    }

    func personDay(profileId: String, day: CalendarDay) -> AnyPublisher<SharingPersonDay, Error> {
        remote.personDay(profileId: profileId, day: day)
    }
}
