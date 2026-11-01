import SwiftData
import SwiftUI

struct SharingScreen: View {
    @Environment(AppDayContext.self) private var dayContext
    @Environment(SharingSyncService.self) private var sharingSyncService
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.isSharingDeviceEnabled) private var isSharingDeviceEnabled = false
    @AppStorage(AppStorageKeys.sharingDisplayName) private var sharingDisplayName = "Me"

    @State private var invite: SharingInvite?
    @State private var inviteToken = ""
    @State private var isSavingProfile = false
    @State private var isCreatingInvite = false
    @State private var isAcceptingInvite = false
    @State private var errorMessage: String?
    @State private var destructiveAction: SharingDestructiveAction?
    @State private var inviteConfirmationInput: String?

    init(initialInviteInput: String? = nil) {
        _inviteToken = State(initialValue: initialInviteInput ?? "")
        _inviteConfirmationInput = State(initialValue: initialInviteInput)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Sharing", isOn: sharingToggleBinding)

                TextField("Display name", text: $sharingDisplayName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .disabled(!isSharingDeviceEnabled)
                if isSharingDeviceEnabled {
                    Button(profileButtonTitle, action: saveProfile)
                        .disabled(isProfileButtonDisabled)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        "Sharing is optional and off by default; when enabled, we send your display name and today’s calories, protein, carbs, fat, and entry count to our Convex backend, and viewers see today only."
                    )
                    Text(
                        "For each person, choose Nothing, Macros, or Macros + Foods; the latter sends today’s food names, amounts, calories, protein, carbs, and fat. Food uploads happen only while you share foods with at least one person; foods are deleted from the server when sharing stops and older days are deleted, while logged times, notes, photos, and barcodes are never sent."
                    )
                    Text(
                        "Invites need Pro, connections work while either person has Pro, and Apple’s signed purchase record (transaction IDs, not personal data) is sent to our server to confirm Pro; you can stop sharing with everyone, remove a person, or delete your profile anytime, which removes stored totals and foods; sharing is best-effort, not medical advice."
                    )
                }
            }

            Section {
                PaidFeatureGate(.sharingInvites) {
                    Button(isCreatingInvite ? "Creating Invite…" : "Create Invite Link") {
                        createInvite()
                    }
                    .disabled(!isSharingDeviceEnabled || isCreatingInvite)

                    if let invite {
                        ShareLink(item: invite.appURL) {
                            Label("Share Invite", systemImage: "square.and.arrow.up")
                        }
                        Text(invite.appURL.absoluteString)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Text("Fallback web link: \(invite.url.absoluteString)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Text("Expires \(invite.expiresAt.formatted(date: .abbreviated, time: .shortened)).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } locked: {
                    ProLockedRow(title: "Create Invite Link", context: .sharingInvites)
                }

                if let invite {
                    Button("Revoke Invite", role: .destructive) {
                        destructiveAction = .revokeInvite(invite)
                    }
                }
            } header: {
                Text("Invite Someone")
            } footer: {
                Text("Creating invites needs MACROS Pro. Anyone you invite can accept and share back for free.")
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
                Text("Expired or revoked invites can’t be accepted.")
            }

            Section {
                Button("Stop Sharing With Everyone", role: .destructive) {
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
        .navigationTitle("Sharing")
        .inlineNavigationTitle()
        .errorBanner(message: $errorMessage, title: "Sharing Failed")
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
            Button(isAcceptingInvite ? "Accepting…" : "Start Sharing") {
                acceptInvite(input: inviteConfirmationInput ?? inviteToken)
            }
            .disabled(!isSharingDeviceEnabled || isAcceptingInvite)

            Button("Cancel", role: .cancel) {
                inviteConfirmationInput = nil
            }
        } message: {
            Text(
                isSharingDeviceEnabled
                    ? "Accept this invite to share current-day macro totals with this person."
                    : "Enable sharing on this device before accepting this invite."
            )
        }
        .task {
            do {
                invite = try sharingSyncService.pendingInvite()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .onChange(of: isSharingDeviceEnabled) { _, enabled in
            if !enabled { invite = nil }
        }
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

    private var sharingToggleBinding: Binding<Bool> {
        Binding(
            get: { isSharingDeviceEnabled },
            set: { enabled in
                if enabled {
                    saveProfile()
                } else {
                    Task {
                        do {
                            try await sharingSyncService.disableSharingOnDevice(ownerDay: dayContext.today)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
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

    private var isAcceptInviteDisabled: Bool {
        !isSharingDeviceEnabled
            || inviteToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || isAcceptingInvite
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
                errorMessage = nil
            } catch {
                errorMessage = "This invite is unavailable."
            }
            isAcceptingInvite = false
        }
    }

    private func perform(_ action: SharingDestructiveAction) {
        Task {
            do {
                switch action {
                case let .revokeInvite(invite):
                    try await revokeInviteAndClear(invite)
                case .stopSharing:
                    try await sharingSyncService.stopSharingMyData(ownerDay: dayContext.today)
                case .deleteProfile:
                    try await sharingSyncService.deleteSharingProfile()
                    invite = nil
                }
                errorMessage = nil
            } catch {
                if !sharingSyncService.isDeviceSharingEnabled { invite = nil }
                errorMessage = error.localizedDescription
            }
            destructiveAction = nil
        }
    }

    private func revokeInviteAndClear(_ invite: SharingInvite) async throws {
        do {
            try await sharingSyncService.revokeInvite(invite)
            self.invite = nil
        } catch {
            self.invite = try? sharingSyncService.pendingInvite()
            throw error
        }
    }
}

private enum SharingDestructiveAction: Identifiable {
    case revokeInvite(SharingInvite)
    case stopSharing
    case deleteProfile

    var id: String {
        switch self {
        case let .revokeInvite(invite):
            "revoke-invite-\(invite.inviteId)"
        case .stopSharing:
            "stop-sharing"
        case .deleteProfile:
            "delete-profile"
        }
    }

    var title: String {
        switch self {
        case .revokeInvite:
            "Revoke invite?"
        case .stopSharing:
            "Stop sharing your data?"
        case .deleteProfile:
            "Delete sharing profile?"
        }
    }

    var buttonTitle: String {
        switch self {
        case .revokeInvite:
            "Revoke Invite"
        case .stopSharing:
            "Stop Sharing"
        case .deleteProfile:
            "Delete Sharing Profile"
        }
    }

    var message: String {
        switch self {
        case .revokeInvite:
            "This invite link will stop working. You can create a new invite later."
        case .stopSharing:
            "This closes all outgoing sharing grants. Existing people remain connected, but your totals will not be shared until you re-enable a person."
        case .deleteProfile:
            "This permanently removes cloud sharing identity, relationships, invites, and uploaded snapshots. Your local food and log data remains on this device."
        }
    }
}
