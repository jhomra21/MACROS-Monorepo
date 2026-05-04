import StoreKit
import SwiftData
import SwiftUI

struct SettingsScreen: View {
    @Query private var goals: [DailyGoals]
    @AppStorage(AppStorageKeys.isFoodSuggestionsEnabled) private var isFoodSuggestionsEnabled = true
    @AppStorage(AppStorageKeys.customProteinRingColor) private var customProteinRingColor =
        MacroRingColorStorage.defaultProteinHex
    @AppStorage(AppStorageKeys.customCarbRingColor) private var customCarbRingColor =
        MacroRingColorStorage.defaultCarbHex
    @AppStorage(AppStorageKeys.customFatRingColor) private var customFatRingColor =
        MacroRingColorStorage.defaultFatHex
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

            MacroRingColorSettingsSection(
                proteinHex: $customProteinRingColor,
                carbHex: $customCarbRingColor,
                fatHex: $customFatRingColor,
                isPresentingFullUnlock: $isPresentingFullUnlock
            )

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

private struct MacroRingColorSettingsSection: View {
    @Environment(AppEntitlements.self) private var entitlements
    @Binding var proteinHex: String
    @Binding var carbHex: String
    @Binding var fatHex: String
    @Binding var isPresentingFullUnlock: Bool

    var body: some View {
        let changedMetrics = changedMetrics

        Section {
            PaidFeatureGate(.customMacroRingColors) {
                ForEach(MacroMetric.allCases) { metric in
                    colorRow(for: metric, changedMetricCount: changedMetrics.count)
                }

                if changedMetrics.count > 1 {
                    Button("Reset Ring Colors") {
                        for metric in changedMetrics {
                            hex(for: metric).wrappedValue = defaultHex(for: metric)
                        }
                    }
                }
            } locked: {
                Button {
                    isPresentingFullUnlock = true
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Customize Macro Ring Colors")
                                .foregroundStyle(Color.accentColor)
                            Text("Unlock Full App to personalize dashboard rings.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Macro Ring Colors")
        } footer: {
            Text(
                entitlements.canUse(.customMacroRingColors)
                    ? "Color changes update the dashboard rings immediately."
                    : "Custom macro ring colors are included with Full App Unlock."
            )
        }
    }

    private var changedMetrics: [MacroMetric] {
        MacroMetric.allCases.filter { hex(for: $0).wrappedValue != defaultHex(for: $0) }
    }

    private func colorRow(for metric: MacroMetric, changedMetricCount: Int) -> some View {
        let title = "\(metric.title) Ring"
        let hex = hex(for: metric)
        let defaultHex = defaultHex(for: metric)
        let color = Color(hex: hex.wrappedValue) ?? .accentColor
        let isChanged = hex.wrappedValue != defaultHex

        return HStack(spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(isChanged ? "Custom color" : "Default color")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if changedMetricCount <= 1, isChanged {
                Button("Reset") {
                    hex.wrappedValue = defaultHex
                }
                .buttonStyle(.glass)
            }

            ColorPicker(title, selection: colorBinding(hex), supportsOpacity: false)
                .labelsHidden()
                .tint(color)
        }
        .padding(.vertical, 4)
    }

    private func hex(for metric: MacroMetric) -> Binding<String> {
        switch metric {
        case .protein:
            $proteinHex
        case .carbs:
            $carbHex
        case .fat:
            $fatHex
        }
    }

    private func defaultHex(for metric: MacroMetric) -> String {
        MacroRingColorStorage.defaultHex(for: metric)
    }

    private func colorBinding(_ hex: Binding<String>) -> Binding<Color> {
        Binding {
            Color(hex: hex.wrappedValue) ?? .accentColor
        } set: { newColor in
            if let newHex = newColor.hexString {
                hex.wrappedValue = newHex
            }
        }
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

            #if DEBUG
            Button(purchaseStore.hasFullUnlock ? "Revoke Debug Unlock" : "Grant Debug Unlock") {
                purchaseStore.setDebugFullUnlock(!purchaseStore.hasFullUnlock)
            }
            #endif
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
