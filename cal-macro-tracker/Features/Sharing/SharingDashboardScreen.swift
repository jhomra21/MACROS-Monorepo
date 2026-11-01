import SwiftUI

struct SharingDashboardScreen: View {
    @Environment(AppDayContext.self) private var dayContext
    @Environment(SharingSyncService.self) private var sharingSyncService
    @State private var dashboardErrorMessage: String?
    let onOpenSharingSettings: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if sharingSyncService.shouldShowDashboardLoading {
                    ProgressView("Loading sharing…")
                } else if sharingSyncService.dashboard.people.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text("No sharing yet")
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Text("Invite someone or accept an invite to see their macros here.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Open Sharing Settings", action: onOpenSharingSettings)
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                } else {
                    ForEach(sharingSyncService.dashboard.people) { person in
                        NavigationLink {
                            SharingPersonScreen(person: person)
                        } label: {
                            SharingPersonRow(person: person)
                        }
                        .accessibilityHint("View \(person.displayName)’s shared day and sharing settings")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle("Sharing")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItemGroup(placement: .appTopBarTrailing) {
                Button(action: onOpenSharingSettings) {
                    Image(systemName: "plus")
                        .appTopBarIconStyle()
                }
                .accessibilityLabel("Invite someone")
                Button(action: onOpenSharingSettings) {
                    Image(systemName: "gearshape")
                        .appTopBarIconStyle()
                }
                .accessibilityLabel("Open sharing settings")
            }
        }
        .onChange(of: sharingSyncService.dashboardErrorMessage) { _, error in
            dashboardErrorMessage = error
        }
        .onAppear {
            dashboardErrorMessage = sharingSyncService.dashboardErrorMessage
        }
        .errorBanner(message: $dashboardErrorMessage, retryTitle: "Retry") {
            sharingSyncService.startDashboardSubscription(for: dayContext.today)
        }
    }
}

private struct SharingPersonRow: View {
    let person: SharingPerson

    private var goals: MacroGoalsSnapshot {
        person.snapshot?.macroGoalsSnapshot ?? .empty
    }

    private var totals: NutritionSnapshot {
        guard let snapshot = person.snapshot else { return .zero }
        return NutritionSnapshot(calories: snapshot.calories, protein: snapshot.protein, fat: snapshot.fat, carbs: snapshot.carbs)
    }

    private var incomingStatus: String {
        guard person.incomingActive, !person.connectionPaused else {
            return "Not sharing with you"
        }
        guard person.snapshot != nil else { return "Sharing with you" }
        return totalsLine
    }

    private var status: String {
        if person.connectionPaused { return "Paused, needs MACROS Pro" }
        return switch person.outgoingScope {
        case .off: "You don’t share with \(person.displayName)"
        case .macros: "Sees your macros"
        case .macrosAndFoods: "Sees your macros and foods"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            if person.incomingActive && !person.connectionPaused, person.snapshot != nil {
                MacroRingSetView(
                    totals: totals,
                    goals: goals,
                    ringDiameter: 68,
                    centerValueFontSize: 15,
                    minimumLineWidth: 5,
                    showsGoalSubtitle: false,
                    usesGlassEffect: false
                )
                .accessibilityHidden(true)
            } else {
                Image(systemName: person.connectionPaused ? "pause.circle" : "person.crop.circle")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                    .frame(width: 68, height: 68)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(person.displayName)
                    .font(.headline)
                Text(incomingStatus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(person.connectionPaused ? .orange : .secondary)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var totalsLine: String {
        "\(totals.calories.roundedForDisplay) kcal · P \(totals.protein.roundedForDisplay)g · C \(totals.carbs.roundedForDisplay)g · F \(totals.fat.roundedForDisplay)g"
    }
}

#Preview("Sharing People") {
    NavigationStack {
        List {
            SharingPersonRow(
                person: SharingPerson(
                    relationshipId: "preview",
                    profileId: "preview-profile",
                    displayName: "Alex",
                    incomingActive: true,
                    outgoingActive: true,
                    scope: SharingScope(macros: true),
                    snapshot: SharedDailySnapshot(
                        day: "2026-11-01",
                        timeZoneId: "America/Los_Angeles",
                        calories: 1_650,
                        protein: 120,
                        fat: 55,
                        carbs: 180,
                        entryCount: 4,
                        updatedAt: 0
                    ),
                    foodsShared: true,
                    outgoingScope: .macrosAndFoods,
                    connectionPaused: false
                )
            )
        }
        .navigationTitle("Sharing")
    }
}
