import SwiftData
import SwiftUI

struct SharingDashboardScreen: View {
    @Environment(AppDayContext.self) private var dayContext
    @Environment(AppEntitlements.self) private var entitlements
    @Environment(SharingSyncService.self) private var sharingSyncService
    @AppStorage(AppStorageKeys.customProteinRingColor, store: .macroRingColors) private var customProteinRingColor =
        MacroRingColorStorage.defaultProteinHex
    @AppStorage(AppStorageKeys.customCarbRingColor, store: .macroRingColors) private var customCarbRingColor =
        MacroRingColorStorage.defaultCarbHex
    @AppStorage(AppStorageKeys.customFatRingColor, store: .macroRingColors) private var customFatRingColor =
        MacroRingColorStorage.defaultFatHex

    let onOpenSharingSettings: () -> Void

    @Query private var goals: [DailyGoals]
    @State private var expandedSharingPersonId: String?
    @State private var errorMessage: String?

    private var currentGoals: MacroGoalsSnapshot {
        MacroGoalsSnapshot(goals: DailyGoals.activeRecord(from: goals))
    }

    private var customRingPalette: MacroRingPalette? {
        guard entitlements.canUse(.customMacroRingColors) else { return nil }
        return MacroRingColorStorage(
            proteinHex: customProteinRingColor,
            carbHex: customCarbRingColor,
            fatHex: customFatRingColor
        )
        .customPalette
    }

    var body: some View {
        ScrollView {
            sharingPreviewContent
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(PlatformColors.groupedBackground)
        .navigationTitle("")
        .inlineNavigationTitle()
        .toolbar {
            AppTopBarLeadingTitle("Sharing")
            ToolbarItem(placement: .appTopBarTrailing) {
                Button(action: onOpenSharingSettings) {
                    Image(systemName: "gearshape")
                        .appTopBarIconStyle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open sharing settings")
            }
        }
        .errorBanner(message: $errorMessage)
        .task(
            id: SharingDashboardSubscriptionKey(
                isDeviceSharingEnabled: sharingSyncService.isDeviceSharingEnabled,
                day: dayContext.today
            )
        ) {
            sharingSyncService.startDashboardSubscription(for: dayContext.today)
        }
        .onChange(of: sharingSyncService.dashboardErrorMessage) { _, message in
            errorMessage = message
        }
    }

    @ViewBuilder
    private var sharingPreviewContent: some View {
        if #available(iOS 26, macOS 26, *) {
            GlassEffectContainer(spacing: 12) {
                sharingPreviewRows
            }
        } else {
            sharingPreviewRows
        }
    }

    private var sharingPreviewRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            if sharingSyncService.dashboard.people.isEmpty {
                sharingEmptyState
            } else {
                ForEach(sharingSyncService.dashboard.people) { person in
                    SharingPreviewPersonRow(
                        person: person,
                        goals: currentGoals,
                        ringColorPalette: customRingPalette,
                        isExpanded: expandedSharingPersonId == person.id,
                        onToggleExpansion: {
                            toggleSharingPersonExpansion(person)
                        },
                        onOutgoingChanged: { enabled in
                            setOutgoingSharing(for: person, enabled: enabled)
                        }
                    )
                }
            }
        }
    }

    private var sharingEmptyState: some View {
        VStack(spacing: 12) {
            ContentUnavailableView(
                "No sharing yet",
                systemImage: "person.2",
                description: Text(
                    sharingSyncService.isDeviceSharingEnabled
                        ? "Invite someone or accept an invite to see shared macro rings here."
                        : "You don't have sharing enabled yet."
                )
            )

            Button(sharingSyncService.isDeviceSharingEnabled ? "Open Sharing Settings" : "Enable Sharing") {
                onOpenSharingSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }

    private func toggleSharingPersonExpansion(_ person: SharingPerson) {
        withAnimation(.smooth(duration: 0.24)) {
            expandedSharingPersonId = expandedSharingPersonId == person.id ? nil : person.id
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
}

private struct SharingPreviewPersonRow: View {
    let person: SharingPerson
    let goals: MacroGoalsSnapshot
    let ringColorPalette: MacroRingPalette?
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onOutgoingChanged: (Bool) -> Void

    private var totals: NutritionSnapshot {
        guard let snapshot = person.snapshot else { return .zero }
        return NutritionSnapshot(
            calories: snapshot.calories,
            protein: snapshot.protein,
            fat: snapshot.fat,
            carbs: snapshot.carbs
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 14 : 0) {
            Button(action: onToggleExpansion) {
                HStack(spacing: 14) {
                    CompactMacroRingView(
                        totals: totals,
                        goals: goals,
                        colorStyle: ringColorPalette.map(MacroRingColorStyle.custom) ?? .standard
                    )
                    .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.displayName)
                            .font(.headline)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Collapse sharing controls" : "Expand sharing controls")

            if isExpanded {
                SharingPreviewExpandedSettings(person: person, onOutgoingChanged: onOutgoingChanged)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .appGlassRoundedRect(cornerRadius: isExpanded ? 28 : 22, interactive: true)
    }

    private var subtitle: String {
        guard let snapshot = person.snapshot else { return "No totals shared yet today" }
        return
            "\(snapshot.calories.roundedForDisplay) kcal · P \(snapshot.protein.roundedForDisplay)g · C \(snapshot.carbs.roundedForDisplay)g · F \(snapshot.fat.roundedForDisplay)g"
    }
}

private struct SharingPreviewExpandedSettings: View {
    let person: SharingPerson
    let onOutgoingChanged: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            HStack(spacing: 10) {
                SharingPreviewStatusPill(title: "Sharing with you", isActive: person.incomingActive)
                SharingPreviewStatusPill(title: "You share", isActive: person.outgoingActive)
            }

            Toggle("Share my macros with \(person.displayName)", isOn: outgoingBinding)
                .font(.subheadline.weight(.semibold))
                .toggleStyle(.switch)
                .padding(.top, 2)
        }
    }

    private var outgoingBinding: Binding<Bool> {
        Binding(
            get: { person.outgoingActive },
            set: { onOutgoingChanged($0) }
        )
    }
}

private struct SharingPreviewStatusPill: View {
    let title: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "minus.circle")
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(isActive ? .green : .secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(.secondary.opacity(0.10), in: Capsule())
    }
}
