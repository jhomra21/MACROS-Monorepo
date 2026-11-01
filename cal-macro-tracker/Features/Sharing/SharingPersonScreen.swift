import Combine
import SwiftData
import SwiftUI

struct SharingPersonScreen: View {
    @Environment(AppDayContext.self) private var dayContext
    @Environment(SharingSyncService.self) private var sharing
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let person: SharingPerson

    @State private var personDay: SharingPersonDay?
    @State private var personDayVisibility: SharingPersonDay.Visibility?
    @State private var errorMessage: String?
    @State private var scopeSelection: SharingScopeSelection
    @State private var showingRemovalConfirmation = false
    @State private var showingProUpgrade = false

    private var currentPerson: SharingPerson {
        sharing.dashboard.people.first { $0.profileId == person.profileId } ?? person
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

            if let snapshot = personDay?.snapshot {
                let sharedGoals = snapshot.macroGoalsSnapshot
                let totals = NutritionSnapshot(
                    calories: snapshot.calories,
                    protein: snapshot.protein,
                    fat: snapshot.fat,
                    carbs: snapshot.carbs
                )
                Section("Today") {
                    MacroRingSetView(
                        totals: totals,
                        goals: sharedGoals ?? .empty,
                        ringDiameter: 156,
                        centerValueFontSize: 24,
                        minimumLineWidth: 10,
                        showsGoalSubtitle: false,
                        usesGlassEffect: false
                    )
                    .frame(maxWidth: .infinity)
                    if let sharedGoals {
                        MacroSummaryColumnsGrid(
                            metrics: [.protein, .carbs, .fat],
                            totals: totals,
                            goals: sharedGoals,
                            style: .compact,
                            columnWidth: 88,
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
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                Section("Today") {
                    ContentUnavailableView(
                        isPaused
                            ? "Sharing is paused"
                            : isNotShared
                                ? "\(currentPerson.displayName) isn't sharing with you"
                                : currentPerson.incomingActive
                                    ? "No macros shared today" : "\(currentPerson.displayName) isn't sharing with you",
                        systemImage: isPaused ? "pause.circle" : "chart.pie"
                    )
                }
            }

            if currentPerson.foodsShared && !isNotShared && !isPaused {
                Section("Foods") {
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
            personDay = nil
            personDayVisibility = nil
            guard sharing.isDeviceSharingEnabled, currentPerson.incomingActive, !currentPerson.connectionPaused else { return }
            do {
                let updates = try await sharing.personDayUpdates(profileId: currentPerson.profileId, day: dayContext.today)
                for try await value in updates.values {
                    try Task.checkCancellation()
                    personDayVisibility = value.visibility
                    if value.visibility == .shared {
                        personDay = value
                    } else {
                        personDay = nil
                    }
                }
            } catch is CancellationError {
            } catch {
                personDay = nil
                errorMessage = error.localizedDescription
            }
        }
        .onChange(of: sharing.isDeviceSharingEnabled) { _, isEnabled in
            if !isEnabled {
                personDay = nil
                personDayVisibility = nil
            }
        }
        .onChange(of: sharing.dashboard) { _, dashboard in
            guard let updatedPerson = dashboard.people.first(where: { $0.profileId == person.profileId }),
                updatedPerson.incomingActive, !updatedPerson.connectionPaused,
                sharing.isDeviceSharingEnabled
            else {
                personDay = nil
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
