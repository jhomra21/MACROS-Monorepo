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
    @State private var errorMessage: String?
    @State private var scopeSelection: SharingScopeSelection
    @State private var showingRemovalConfirmation = false
    @State private var showingProUpgrade = false

    init(person: SharingPerson) {
        self.person = person
        _scopeSelection = State(initialValue: SharingScopeSelection(scope: person.outgoingScope))
    }

    var body: some View {
        List {
            if person.connectionPaused {
                Section {
                    Label("Sharing is paused because neither person has MACROS Pro.", systemImage: "pause.circle")
                    Button("Upgrade to MACROS Pro") { showingProUpgrade = true }
                }
            }

            if let snapshot = personDay?.snapshot {
                let totals = NutritionSnapshot(
                    calories: snapshot.calories,
                    protein: snapshot.protein,
                    fat: snapshot.fat,
                    carbs: snapshot.carbs
                )
                Section("Today") {
                    MacroRingSetView(
                        totals: totals,
                        goals: .default,
                        ringDiameter: 156,
                        centerValueFontSize: 24,
                        minimumLineWidth: 10,
                        showsGoalSubtitle: false,
                        usesGlassEffect: false
                    )
                    .frame(maxWidth: .infinity)
                    MacroSummaryColumnsGrid(
                        metrics: [.protein, .carbs, .fat],
                        totals: totals,
                        goals: .default,
                        style: .compact,
                        columnWidth: 88,
                        columnSpacing: 8
                    )
                }
            } else {
                Section("Today") {
                    ContentUnavailableView("No macros shared", systemImage: "chart.pie")
                }
            }

            if person.foodsShared {
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

            Section("What \(person.displayName) sees from you") {
                Picker(
                    "Sharing scope",
                    selection: Binding(
                        get: { scopeSelection.selected },
                        set: { updateScope($0) }
                    )
                ) {
                    Text("Nothing").tag(SharingOutgoingScope.off)
                    Text("Macros").tag(SharingOutgoingScope.macros)
                    Text("Macros + Foods").tag(SharingOutgoingScope.macrosAndFoods).disabled(person.connectionPaused)
                }
                .pickerStyle(.segmented)
                .disabled(scopeSelection.isWriteInFlight)
                .accessibilityLabel("What \(person.displayName) sees from you")
            }

            Section {
                Button("Remove \(person.displayName)", role: .destructive) {
                    showingRemovalConfirmation = true
                }
            }
        }
        .navigationTitle(person.displayName)
        .inlineNavigationTitle()
        .errorBanner(message: $errorMessage, title: "Sharing Failed")
        .sheet(isPresented: $showingProUpgrade) {
            ProPaywallSheet(context: .sharingInvites)
        }
        .confirmationDialog(
            "Remove \(person.displayName)?",
            isPresented: $showingRemovalConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Person", role: .destructive) {
                Task {
                    do {
                        try await sharing.removePerson(person.profileId, ownerDay: dayContext.today)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } message: {
            Text("This removes the relationship for both people. Reconnecting requires a new invite.")
        }
        .task(id: dayContext.today.sharingDayKey) {
            personDay = nil
            guard sharing.isDeviceSharingEnabled, !person.connectionPaused else { return }
            do {
                let updates = try await sharing.personDayUpdates(profileId: person.profileId, day: dayContext.today)
                for try await value in updates.values {
                    try Task.checkCancellation()
                    personDay = value
                }
            } catch is CancellationError {
            } catch {
                personDay = nil
                errorMessage = error.localizedDescription
            }
        }
        .onChange(of: sharing.isDeviceSharingEnabled) { _, isEnabled in
            if !isEnabled { personDay = nil }
        }
        .onChange(of: sharing.dashboard) { _, _ in
            if !sharing.isDeviceSharingEnabled { personDay = nil }
        }
        .onChange(of: person.outgoingScope) { _, newScope in
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
