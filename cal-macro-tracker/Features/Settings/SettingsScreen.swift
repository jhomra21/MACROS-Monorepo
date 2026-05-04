import StoreKit
import SwiftData
import SwiftUI

struct SettingsScreen: View {
    @Query private var goals: [DailyGoals]
    @AppStorage(AppStorageKeys.isFoodSuggestionsEnabled) private var isFoodSuggestionsEnabled = true
    @FocusState private var focusedField: DailyGoalsField?
    @State private var isPresentingFullUnlock = false

    var body: some View {
        Form {
            if let goals = activeGoals {
                SettingsGoalsEditorSection(goals: goals, focusedField: $focusedField)
            }

            Section {
                Toggle("Food Suggestions", isOn: $isFoodSuggestionsEnabled)
            } footer: {
                Text("Suggest foods from your on-device logging history.")
            }

            FullUnlockSettingsSection(isPresentingFullUnlock: $isPresentingFullUnlock)

            SavedFoodsSection(
                title: "Saved Custom Foods",
                emptyState: "Custom foods you save while logging will show up here.",
                descriptor: Self.customFoodsDescriptor
            )
            SavedFoodsSection(
                title: "Saved External Foods",
                emptyState: "Barcode, label scan, and online packaged foods you save locally will show up here.",
                descriptor: Self.externalFoodsDescriptor
            )
        }
        .scrollDismissesKeyboard(.interactively)
        .keyboardNavigationToolbar(focusedField: $focusedField, fields: DailyGoalsField.formOrder)
        .navigationTitle("")
        .inlineNavigationTitle()
        .toolbar {
            AppTopBarLeadingTitle("Settings")
        }
        .onDisappear {
            dismissKeyboard($focusedField)
        }
        .sheet(isPresented: $isPresentingFullUnlock) {
            FullUnlockPaywallSheet()
                .presentationDetents([.medium, .large])
        }
    }

    private var activeGoals: DailyGoals? {
        DailyGoals.activeRecord(from: goals)
    }

    private static var customFoodsDescriptor: FetchDescriptor<FoodItem> {
        let customSource = FoodSource.custom.rawValue
        return FetchDescriptor<FoodItem>(
            predicate: #Predicate<FoodItem> { food in
                food.source == customSource
            },
            sortBy: [SortDescriptor(\FoodItem.name)]
        )
    }

    private static var externalFoodsDescriptor: FetchDescriptor<FoodItem> {
        let barcodeLookupSource = FoodSource.barcodeLookup.rawValue
        let labelScanSource = FoodSource.labelScan.rawValue
        let searchLookupSource = FoodSource.searchLookup.rawValue
        return FetchDescriptor<FoodItem>(
            predicate: #Predicate<FoodItem> { food in
                food.source == barcodeLookupSource
                    || food.source == labelScanSource
                    || food.source == searchLookupSource
            },
            sortBy: [SortDescriptor(\FoodItem.name)]
        )
    }
}

private struct FullUnlockSettingsSection: View {
    @Environment(PurchaseStore.self) private var purchaseStore
    @Binding var isPresentingFullUnlock: Bool

    var body: some View {
        Section {
            fullUnlockStatusButton(isUnlocked: purchaseStore.hasFullUnlock)

            Button("Restore Purchases") {
                Task {
                    await purchaseStore.restorePurchases()
                }
            }
            .disabled(purchaseStore.isPurchasing)
        } footer: {
            Text("Purchases are processed by Apple. Restore anytime with the same Apple ID.")
        }
        .task {
            await purchaseStore.loadProducts()
        }
    }

    private func fullUnlockStatusButton(isUnlocked: Bool) -> some View {
        Button {
            isPresentingFullUnlock = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isUnlocked ? "Full App Unlocked" : "Unlock Full App")
                        .foregroundStyle(isUnlocked ? Color.primary : Color.accentColor)
                    Text(isUnlocked ? "All paid features are available." : "Unlock all features with one purchase.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if purchaseStore.isLoadingProducts {
                    ProgressView()
                } else if !isUnlocked, let product = purchaseStore.fullUnlockProduct {
                    Text(product.displayPrice)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SavedFoodsSection: View {
    let title: String
    let emptyState: String
    @Query private var foods: [FoodItem]

    init(title: String, emptyState: String, descriptor: FetchDescriptor<FoodItem>) {
        self.title = title
        self.emptyState = emptyState
        _foods = Query(descriptor)
    }

    var body: some View {
        Section(title) {
            if foods.isEmpty {
                Text(emptyState)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(foods) { food in
                    NavigationLink {
                        ReusableFoodEditorScreen(food: food)
                    } label: {
                        SavedFoodRow(food: food)
                    }
                }
            }
        }
    }
}

private struct SavedFoodRow: View {
    let food: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(food.name)
                .font(.headline)
            Text("\(food.caloriesPerServing.roundedForDisplay) kcal • \(food.servingDescription)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
