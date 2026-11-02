import Combine
import SwiftData
import SwiftUI

struct SharingPersonScreen: View {
    @Environment(AppDayContext.self) private var dayContext
    @Environment(SharingSyncService.self) private var sharing
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let person: SharingPerson

    @State private var personDayVisibility: SharingPersonDay.Visibility?
    @State private var isLoadingPersonDay = true
    @State private var errorMessage: String?
    @State private var scopeSelection: SharingScopeSelection
    @State private var showingRemovalConfirmation = false
    @State private var showingProUpgrade = false

    private var currentPerson: SharingPerson {
        sharing.dashboard.people.first { $0.profileId == person.profileId } ?? person
    }

    private var personDay: SharingPersonDay? {
        sharing.cachedPersonDay(profileId: person.profileId, day: dayContext.today)
    }

    /// The live day when cached, otherwise the dashboard snapshot, which the server leaves empty unless the day is visible.
    private var displayedSnapshot: SharedDailySnapshot? {
        guard !isPaused, !isNotShared else { return nil }
        return personDay?.snapshot ?? currentPerson.snapshot
    }

    private var isAwaitingPersonDay: Bool {
        isLoadingPersonDay && personDay == nil
    }

    init(person: SharingPerson) {
        self.person = person
        _scopeSelection = State(initialValue: SharingScopeSelection(scope: person.outgoingScope))
    }

    var body: some View {
        List {
            if isPaused {
                Section {
                    Label("Sharing is paused because neither person has MACROS Pro.", systemImage: "pause.circle")
                    Button("Upgrade to MACROS Pro") { showingProUpgrade = true }
                }
            }

            if let snapshot = displayedSnapshot {
                let sharedGoals = snapshot.macroGoalsSnapshot
                let totals = NutritionSnapshot(
                    calories: snapshot.calories,
                    protein: snapshot.protein,
                    fat: snapshot.fat,
                    carbs: snapshot.carbs
                )
                Section("Today") {
                    // One row: separate rows would draw a separator between the rings and the legend.
                    VStack(spacing: 20) {
                        MacroRingSetView(
                            totals: totals,
                            goals: sharedGoals ?? .empty,
                            ringDiameter: 180,
                            centerValueFontSize: 30,
                            minimumLineWidth: 10,
                            showsGoalSubtitle: false,
                            usesGlassEffect: false
                        )
                        if let sharedGoals {
                            MacroSummaryColumnsGrid(
                                metrics: [.protein, .carbs, .fat],
                                totals: totals,
                                goals: sharedGoals,
                                style: .dashboardCard,
                                columnWidth: 92,
                                columnSpacing: 8
                            )
                        } else {
                            HStack(spacing: 16) {
                                Text("P \(totals.protein.roundedForDisplay) g")
                                Text("C \(totals.carbs.roundedForDisplay) g")
                                Text("F \(totals.fat.roundedForDisplay) g")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            } else {
                Section("Today") {
                    if isAwaitingPersonDay && !isPaused && !isNotShared {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        ContentUnavailableView(
                            isPaused
                                ? "Sharing is paused"
                                : isNotShared ? "\(currentPerson.displayName) isn't sharing with you" : "No macros shared today",
                            systemImage: isPaused ? "pause.circle" : "chart.pie"
                        )
                    }
                }
            }

            if currentPerson.foodsShared && !isNotShared && !isPaused {
                Section("Foods") {
                    if isAwaitingPersonDay {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(personDay?.foods ?? []) { food in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(food.name).font(.headline)
                                Spacer()
                                Text("\(food.calories.roundedForDisplay) kcal")
                                    .foregroundStyle(.secondary)
                            }
                            Text(
                                "\(food.quantityText) · P \(food.protein.roundedForDisplay)g · C \(food.carbs.roundedForDisplay)g · F \(food.fat.roundedForDisplay)g"
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            Section("What \(currentPerson.displayName) sees from you") {
                Picker(
                    "Sharing scope",
                    selection: Binding(
                        get: { scopeSelection.selected },
                        set: { updateScope($0) }
                    )
                ) {
                    Text("Nothing").tag(SharingOutgoingScope.off)
                    Text("Macros").tag(SharingOutgoingScope.macros)
                    Text("Macros + Foods").tag(SharingOutgoingScope.macrosAndFoods).disabled(isPaused)
                }
                .pickerStyle(.segmented)
                .disabled(scopeSelection.isWriteInFlight)
                .accessibilityLabel("What \(currentPerson.displayName) sees from you")
            }

            Section {
                Button("Remove \(currentPerson.displayName)", role: .destructive) {
                    showingRemovalConfirmation = true
                }
            }
        }
        .navigationTitle(currentPerson.displayName)
        .inlineNavigationTitle()
        .errorBanner(message: $errorMessage, title: "Sharing Failed")
        .sheet(isPresented: $showingProUpgrade) {
            ProPaywallSheet(context: .sharingInvites)
        }
        .confirmationDialog(
            "Remove \(currentPerson.displayName)?",
            isPresented: $showingRemovalConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Person", role: .destructive) {
                Task {
                    do {
                        try await sharing.removePerson(currentPerson.profileId, ownerDay: dayContext.today)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } message: {
            Text("This removes the relationship for both people. Reconnecting requires a new invite.")
        }
        .task(
            id:
                "\(dayContext.today.sharingDayKey)-\(currentPerson.profileId)-\(currentPerson.incomingActive)-\(currentPerson.connectionPaused)-\(sharing.isDeviceSharingEnabled)"
        ) {
            personDayVisibility = nil
            isLoadingPersonDay = true
            guard sharing.isDeviceSharingEnabled, currentPerson.incomingActive, !currentPerson.connectionPaused else { return }
            do {
                let day = dayContext.today
                let updates = try await sharing.personDayUpdates(profileId: currentPerson.profileId, day: day)
                for try await value in updates.values {
                    try Task.checkCancellation()
                    personDayVisibility = value.visibility
                    sharing.cachePersonDay(value, profileId: currentPerson.profileId, day: day)
                    isLoadingPersonDay = false
                }
            } catch is CancellationError {
            } catch {
                isLoadingPersonDay = false
                errorMessage = error.localizedDescription
            }
        }
        .onChange(of: sharing.isDeviceSharingEnabled) { _, isEnabled in
            if !isEnabled { personDayVisibility = nil }
        }
        .onChange(of: sharing.dashboard) { _, dashboard in
            guard let updatedPerson = dashboard.people.first(where: { $0.profileId == person.profileId }),
                updatedPerson.incomingActive, !updatedPerson.connectionPaused,
                sharing.isDeviceSharingEnabled
            else {
                personDayVisibility = nil
                return
            }
        }
        .onChange(of: currentPerson.outgoingScope) { _, newScope in
            scopeSelection.acceptServerScope(newScope)
        }
    }

    private func updateScope(_ scope: SharingOutgoingScope) {
        guard scopeSelection.beginWrite(scope) else { return }
        Task {
            do {
                try await sharing.setOutgoingScope(
                    to: person.profileId,
                    scope: scope,
                    ownerDay: dayContext.today,
                    container: modelContext.container
                )
                scopeSelection.confirmWrite(scope)
            } catch {
                errorMessage = error.localizedDescription
                scopeSelection.rejectWrite()
            }
        }
    }

    private var isPaused: Bool {
        currentPerson.connectionPaused || personDayVisibility == .paused
    }

    private var isNotShared: Bool {
        !currentPerson.incomingActive || personDayVisibility == .notShared
    }
}

struct SharingScopeSelection: Equatable {
    private(set) var selected: SharingOutgoingScope
    private(set) var confirmed: SharingOutgoingScope
    private(set) var isWriteInFlight = false

    init(scope: SharingOutgoingScope) {
        selected = scope
        confirmed = scope
    }

    mutating func beginWrite(_ scope: SharingOutgoingScope) -> Bool {
        guard !isWriteInFlight, scope != confirmed else { return false }
        selected = scope
        isWriteInFlight = true
        return true
    }

    mutating func confirmWrite(_ scope: SharingOutgoingScope) {
        selected = scope
        confirmed = scope
        isWriteInFlight = false
    }

    mutating func rejectWrite() {
        selected = confirmed
        isWriteInFlight = false
    }

    mutating func acceptServerScope(_ scope: SharingOutgoingScope) {
        selected = scope
        confirmed = scope
    }
}

#Preview("Sharing Person") {
    NavigationStack {
        SharingPersonScreen(
            person: SharingPerson(
                relationshipId: "preview",
                profileId: "preview-profile",
                displayName: "Alex",
                incomingActive: true,
                outgoingActive: true,
                scope: SharingScope(macros: true),
                snapshot: nil,
                foodsShared: true,
                outgoingScope: .macros,
                connectionPaused: false
            )
        )
    }
}
