import Combine
import SwiftData
import SwiftUI

struct SharingScreen: View {
    @Environment(AppDayContext.self) private var dayContext
    @Environment(SharingSyncService.self) private var sharingSyncService
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.isSharingDeviceEnabled) private var isSharingDeviceEnabled = false
    @AppStorage(AppStorageKeys.sharingDisplayName) private var sharingDisplayName = "Me"

    @State private var dashboard = SharingDashboard(people: [])
    @State private var invite: SharingInvite?
    @State private var inviteToken = ""
    @State private var isSavingProfile = false
    @State private var isCreatingInvite = false
    @State private var isAcceptingInvite = false
    @State private var errorMessage: String?
    @State private var destructiveAction: SharingDestructiveAction?
    @State private var inviteConfirmationInput: String?
    @State private var dashboardRefreshToken = 0

    init(initialInviteInput: String? = nil) {
        _inviteToken = State(initialValue: initialInviteInput ?? "")
        _inviteConfirmationInput = State(initialValue: initialInviteInput)
    }

    var body: some View {
        Form {
            Section {
                TextField("Display name", text: $sharingDisplayName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                Button(profileButtonTitle) {
                    saveProfile()
                }
                .disabled(isProfileButtonDisabled)

                if isSharingDeviceEnabled {
                    Button("Turn Off Sharing on This Device", role: .destructive) {
                        destructiveAction = .turnOffDevice
                    }
                }

                Button("Sync Shared Totals Now") {
                    syncNow()
                }
                .disabled(!isSharingDeviceEnabled)
            } footer: {
                Text("Shared totals are best-effort and may be delayed. They are not medical advice.")
            }

            Section("Invite Someone") {
                Button(isCreatingInvite ? "Creating Invite…" : "Create Invite Link") {
                    createInvite()
                }
                .disabled(!isSharingDeviceEnabled || isCreatingInvite)

                if let invite {
                    ShareLink(item: invite.appURL) {
                        Text(invite.appURL.absoluteString)
                            .lineLimit(2)
                    }
                    Text("Fallback web link: \(invite.url.absoluteString)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Button("Revoke Invite", role: .destructive) {
                        destructiveAction = .revokeInvite(invite)
                    }
                    Text("Expires \(invite.expiresAt.formatted(date: .abbreviated, time: .shortened)).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                TextField("Invite token or link", text: $inviteToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button(isAcceptingInvite ? "Accepting…" : "Accept Invite") {
                    confirmInviteAcceptance(inviteToken)
                }
                .disabled(isAcceptInviteDisabled)
            } header: {
                Text("Accept Invite")
            } footer: {
                Text("If an invite is expired, revoked, or invalid, this invite is unavailable.")
            }

            Section("People") {
                if dashboard.people.isEmpty {
                    ContentUnavailableView(
                        "No shared data available for today.",
                        systemImage: "person.2",
                        description: Text("Invite someone or accept an invite to start sharing current-day macro totals.")
                    )
                } else {
                    ForEach(dashboard.people) { person in
                        SharingPersonRow(
                            person: person,
                            onOutgoingChanged: { enabled in
                                setOutgoingSharing(for: person, enabled: enabled)
                            },
                            onRemove: {
                                destructiveAction = .removePerson(person)
                            }
                        )
                    }
                }
            }

            Section {
                Button("Stop Sharing My Data", role: .destructive) {
                    destructiveAction = .stopSharing
                }
                .disabled(!isSharingDeviceEnabled)

                Button("Delete Sharing Profile", role: .destructive) {
                    destructiveAction = .deleteProfile
                }
            } footer: {
                Text(
                    "Deleting your sharing profile permanently removes cloud sharing data and relationships. Local food and log data stays on this device."
                )
            }
        }
        .navigationTitle("")
        .inlineNavigationTitle()
        .toolbar {
            AppTopBarLeadingTitle("Sharing")
        }
        .errorBanner(message: $errorMessage)
        .alert(
            destructiveAction?.title ?? "",
            isPresented: destructiveActionBinding,
        ) {
            if let destructiveAction {
                Button(destructiveAction.buttonTitle, role: .destructive) {
                    perform(destructiveAction)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let destructiveAction {
                Text(destructiveAction.message)
            }
        }
        .alert(
            "Start Sharing?",
            isPresented: inviteConfirmationBinding,
        ) {
            Button(isAcceptingInvite ? "Accepting…" : "Yes, Start Sharing") {
                acceptInvite(input: inviteConfirmationInput ?? inviteToken)
            }
            .disabled(!isSharingDeviceEnabled || isAcceptingInvite)

            Button("No", role: .cancel) {
                inviteConfirmationInput = nil
            }
        } message: {
            Text(
                isSharingDeviceEnabled
                    ? "Accept this invite to share current-day macro totals with this person."
                    : "Enable sharing on this device before accepting this invite."
            )
        }
        .task(id: dashboardTaskId) {
            guard isSharingDeviceEnabled else { return }
            await observeDashboard()
        }
        .task {
            invite = sharingSyncService.pendingInvite()
        }
    }

    private var dashboardTaskId: String {
        "\(isSharingDeviceEnabled)-\(dashboardRefreshToken)-\(dayContext.today)"
    }

    private var destructiveActionBinding: Binding<Bool> {
        Binding(
            get: { destructiveAction != nil },
            set: { if !$0 { destructiveAction = nil } }
        )
    }

    private var inviteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { inviteConfirmationInput != nil },
            set: { if !$0 { inviteConfirmationInput = nil } }
        )
    }

    private var profileButtonTitle: String {
        if isSavingProfile {
            return isSharingDeviceEnabled ? "Saving…" : "Enabling…"
        }
        return isSharingDeviceEnabled ? "Save Display Name" : "Enable Sharing"
    }

    private var isProfileButtonDisabled: Bool {
        isSavingProfile || normalizedSharingDisplayName.isEmpty
    }

    private var normalizedSharingDisplayName: String {
        sharingDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func observeDashboard() async {
        do {
            try await sharingSyncService.prepareDashboardSubscription()
            let values = sharingSyncService.dashboard(for: dayContext.today).values
            for try await dashboard in values {
                self.dashboard = dashboard
                errorMessage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var isAcceptInviteDisabled: Bool {
        !isSharingDeviceEnabled
            || inviteToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || isAcceptingInvite
    }

    private func syncNow() {
        Task {
            await sharingSyncService.syncTodayIfConfigured(container: modelContext.container)
        }
    }

    private func saveProfile() {
        let displayName = normalizedSharingDisplayName
        isSavingProfile = true
        Task {
            do {
                if isSharingDeviceEnabled {
                    try await sharingSyncService.updateDisplayName(displayName)
                } else {
                    try await sharingSyncService.enableSharing(displayName: displayName, container: modelContext.container)
                }
                sharingDisplayName = displayName
                dashboardRefreshToken += 1
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isSavingProfile = false
        }
    }

    private func createInvite() {
        isCreatingInvite = true
        Task {
            do {
                invite = try await sharingSyncService.createInvite()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreatingInvite = false
        }
    }

    private func revokeInvite(_ invite: SharingInvite) {
        Task {
            do {
                try await revokeInviteAndClear(invite)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func confirmInviteAcceptance(_ input: String) {
        inviteConfirmationInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func acceptInvite(input: String) {
        guard isSharingDeviceEnabled else {
            errorMessage = "Enable sharing on this device before accepting this invite."
            return
        }
        let token = input.trimmingCharacters(in: .whitespacesAndNewlines)
        isAcceptingInvite = true
        Task {
            do {
                try await sharingSyncService.acceptInvite(input: token, ownerDay: dayContext.today)
                inviteToken = ""
                inviteConfirmationInput = nil
                dashboardRefreshToken += 1
                errorMessage = nil
            } catch {
                errorMessage = "This invite is unavailable."
            }
            isAcceptingInvite = false
        }
    }

    private func setOutgoingSharing(for person: SharingPerson, enabled: Bool) {
        Task {
            do {
                try await sharingSyncService.setOutgoingSharing(to: person.profileId, enabled: enabled, ownerDay: dayContext.today)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func perform(_ action: SharingDestructiveAction) {
        Task {
            do {
                switch action {
                case let .revokeInvite(invite):
                    try await revokeInviteAndClear(invite)
                case .turnOffDevice:
                    try await sharingSyncService.stopSharingMyData(ownerDay: dayContext.today)
                    isSharingDeviceEnabled = false
                    dashboard = SharingDashboard(people: [])
                case .stopSharing:
                    try await sharingSyncService.stopSharingMyData(ownerDay: dayContext.today)
                case let .removePerson(person):
                    try await sharingSyncService.removePerson(person.profileId, ownerDay: dayContext.today)
                case .deleteProfile:
                    try await sharingSyncService.deleteSharingProfile()
                    dashboard = SharingDashboard(people: [])
                    invite = nil
                }
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            destructiveAction = nil
        }
    }

    private func revokeInviteAndClear(_ invite: SharingInvite) async throws {
        try await sharingSyncService.revokeInvite(invite)
        self.invite = nil
    }
}

private struct SharingPersonRow: View {
    let person: SharingPerson
    let onOutgoingChanged: (Bool) -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.displayName)
                        .font(.headline)
                    Text(statusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if let snapshot = person.snapshot {
                sharedMacroSummary(snapshot)
                Text(updatedText(for: snapshot))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("No shared data available for today.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Toggle("Share my totals with \(person.displayName)", isOn: outgoingBinding)

            Button("Remove Person", role: .destructive) {
                onRemove()
            }
        }
        .padding(.vertical, 4)
    }

    private var outgoingBinding: Binding<Bool> {
        Binding(
            get: { person.outgoingActive },
            set: { onOutgoingChanged($0) }
        )
    }

    private func updatedText(for snapshot: SharedDailySnapshot) -> String {
        let updatedAt = Date(timeIntervalSince1970: snapshot.updatedAt / 1000)
            .formatted(.relative(presentation: .named))
        return "Owner timezone: \(snapshot.timeZoneId) • Updated \(updatedAt)"
    }

    private func sharedMacroSummary(_ snapshot: SharedDailySnapshot) -> some View {
        let totals = NutritionSnapshot(
            calories: snapshot.calories,
            protein: snapshot.protein,
            fat: snapshot.fat,
            carbs: snapshot.carbs
        )

        return HStack(spacing: 8) {
            VStack(spacing: 4) {
                Text("\(snapshot.calories.roundedForDisplay)")
                    .font(.headline.weight(.semibold))
                Text("kcal")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            MacroSummaryColumnView(
                metric: .protein,
                totals: totals,
                goals: .default,
                titleStyle: .short,
                style: .compact
            )
            MacroSummaryColumnView(
                metric: .carbs,
                totals: totals,
                goals: .default,
                titleStyle: .short,
                style: .compact
            )
            MacroSummaryColumnView(
                metric: .fat,
                totals: totals,
                goals: .default,
                titleStyle: .short,
                style: .compact
            )
        }
    }

    private var statusText: String {
        switch (person.incomingActive, person.outgoingActive) {
        case (true, true):
            "Sharing both ways"
        case (true, false):
            "Sharing with you"
        case (false, true):
            "You are sharing"
        case (false, false):
            "Sharing paused"
        }
    }
}

private enum SharingDestructiveAction: Identifiable {
    case revokeInvite(SharingInvite)
    case turnOffDevice
    case stopSharing
    case removePerson(SharingPerson)
    case deleteProfile

    var id: String {
        switch self {
        case let .revokeInvite(invite):
            "revoke-invite-\(invite.inviteId)"
        case .turnOffDevice:
            "turn-off-device"
        case .stopSharing:
            "stop-sharing"
        case let .removePerson(person):
            "remove-\(person.id)"
        case .deleteProfile:
            "delete-profile"
        }
    }

    var title: String {
        switch self {
        case .revokeInvite:
            "Revoke invite?"
        case .turnOffDevice:
            "Turn off sharing on this device?"
        case .stopSharing:
            "Stop sharing your data?"
        case let .removePerson(person):
            "Remove \(person.displayName)?"
        case .deleteProfile:
            "Delete sharing profile?"
        }
    }

    var buttonTitle: String {
        switch self {
        case .revokeInvite:
            "Revoke Invite"
        case .turnOffDevice:
            "Turn Off Sharing"
        case .stopSharing:
            "Stop Sharing"
        case .removePerson:
            "Remove Person"
        case .deleteProfile:
            "Delete Sharing Profile"
        }
    }

    var message: String {
        switch self {
        case .revokeInvite:
            "This invite link will stop working. You can create a new invite later."
        case .turnOffDevice:
            "This stops uploads and closes outgoing sharing grants. You can re-enable sharing later with this device identity."
        case .stopSharing:
            "This closes all outgoing sharing grants. Existing people remain connected, but your totals will not be shared until you re-enable a person."
        case .removePerson:
            "This removes the relationship for both people. Reconnecting requires a new invite."
        case .deleteProfile:
            "This permanently removes cloud sharing identity, relationships, invites, and uploaded snapshots. Your local food and log data remains on this device."
        }
    }
}
