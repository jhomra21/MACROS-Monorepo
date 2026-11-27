import SwiftData
import SwiftUI
import UIKit

/// Review step for a meal photo: confirm foods and amounts, answer the oil question, then log through the normal path.
struct MealPhotoScanScreen: View {
    private enum PickerTarget: Identifiable {
        case replace(UUID)
        case add

        var id: String {
            switch self {
            case let .replace(id): id.uuidString
            case .add: "add"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Environment(AppEntitlements.self) private var entitlements
    @Environment(SharingSyncService.self) private var sharingSyncService
    @AppStorage(AppStorageKeys.mealPhotoTrialScansUsed) private var trialScansUsed = 0

    let capture: MealPhotoCapture
    let loggingDay: CalendarDay?
    let onFoodLogged: () -> Void

    @State private var session = MealPhotoSession()
    @State private var attempt = 0
    @State private var pickerTarget: PickerTarget?
    @State private var isOilPromptPresented = false
    @State private var errorMessage: String?
    @State private var logFeedbackToken = 0
    @FocusState private var focusedItemID: UUID?

    private var matcher: MealPhotoMatcher { MealPhotoMatcher(modelContext: modelContext) }

    private var totalCalories: Double {
        session.items.reduce(0) { $0 + $1.nutrients.calories }
    }

    var body: some View {
        content
            .navigationTitle("Scan a Meal")
            .inlineNavigationTitle()
            .task(id: attempt) {
                await session.scan(capture.image, matcher: matcher) {
                    trialScansUsed = MealPhotoTrial.used(afterSuccessfulScan: trialScansUsed, hasPro: entitlements.hasPro)
                }
            }
            .onDisappear { session.finish() }
            .errorBanner(message: $errorMessage)
            .sensoryFeedback(.success, trigger: logFeedbackToken)
    }

    @ViewBuilder
    private var content: some View {
        switch session.phase {
        case .estimating:
            ProgressView("Looking at your meal…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("meal-photo-analyzing")
        case let .message(message):
            messageView(message)
        case .review:
            review
        }
    }

    private func messageView(_ message: MealPhotoMessage) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(message.title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(message.detail)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if message.canRetry {
                    Button("Try Again") { attempt += 1 }
                        .buttonStyle(.glassProminent)
                }
                Button("Search Instead") { dismiss() }
                    .buttonStyle(.glass)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    private var review: some View {
        List {
            Section {
                ForEach($session.items) { $item in
                    let id = item.id
                    MealPhotoItemRow(
                        item: $item,
                        amountFocus: $focusedItemID,
                        onChangeFood: { pickerTarget = .replace(id) }
                    )
                    .swipeActions {
                        Button("Remove", role: .destructive) { remove(id) }
                    }
                    .accessibilityAction(named: "Remove") { remove(id) }
                }
                Button("Add Food", systemImage: "plus") { pickerTarget = .add }
            } footer: {
                Text(footer)
            }
            Section {
                LabeledContent("Total", value: "\(totalCalories.formatted(.number.precision(.fractionLength(0)))) kcal")
                    .font(.headline)
                    .monospacedDigit()
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedItemID = nil }
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomPinnedActionBar(title: "Log Meal", systemImage: nil, isDisabled: !session.canLog) {
                focusedItemID = nil
                if session.hiddenFatAnswer == nil {
                    isOilPromptPresented = true
                } else {
                    logMeal()
                }
            }
        }
        .sheet(item: $pickerTarget) { target in
            NavigationStack {
                MealComponentFoodPickerScreen(excludedFoodIDs: []) { component in
                    choose(FoodDraft(foodItem: component.food, saveAsCustomFood: false), for: target)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { pickerTarget = nil }
                    }
                }
            }
        }
        .alert("Did you add oil, butter or dressing?", isPresented: $isOilPromptPresented) {
            Button("Yes") {
                session.addOilItem(matcher: matcher)
            }
            Button("No") {
                session.hiddenFatAnswer = .no
                logMeal()
            }
            Button("Skip") {
                session.hiddenFatAnswer = .skipped
                logMeal()
            }
        } message: {
            Text("Cooking fat is hard to see in a photo. Yes adds a tablespoon of olive oil you can edit.")
        }
    }

    private var footer: String {
        if !session.canLog { return "Choose a food and an amount for each item to continue. Remove anything that isn't on your plate." }
        return "Check each food and amount. Calories come from the matched food, not from the photo."
    }

    private func choose(_ food: FoodDraft, for target: PickerTarget) {
        switch target {
        case let .replace(id):
            session.replaceFood(of: id, with: food)
        case .add:
            session.items.append(.added(food: food))
        }
    }

    private func remove(_ id: UUID) {
        session.items.removeAll { $0.id == id }
    }

    private func logMeal() {
        let repository = LogEntryRepository(
            modelContext: modelContext, onDailyTotalsChanged: sharingSyncService.syncAfterDailyTotalsChange)
        do {
            try session.log(using: repository, at: loggingDay?.date(matchingTimeOf: .now) ?? .now)
            logFeedbackToken += 1
            onFoodLogged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
