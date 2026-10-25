import StoreKit
import SwiftData
import SwiftUI
#if os(iOS)
import ObjectiveC
#endif

struct SettingsScreen: View {
    @Environment(SharingSyncService.self) private var sharingSyncService
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [DailyGoals]
    @AppStorage(AppStorageKeys.isFoodSuggestionsEnabled) private var isFoodSuggestionsEnabled = true
    @AppStorage(AppStorageKeys.isSharingDeviceEnabled) private var isSharingDeviceEnabled = false
    @AppStorage(AppStorageKeys.customProteinRingColor, store: .macroRingColors) private var customProteinRingColor =
        MacroRingColorStorage.defaultProteinHex
    @AppStorage(AppStorageKeys.customCarbRingColor, store: .macroRingColors) private var customCarbRingColor =
        MacroRingColorStorage.defaultCarbHex
    @AppStorage(AppStorageKeys.customFatRingColor, store: .macroRingColors) private var customFatRingColor =
        MacroRingColorStorage.defaultFatHex
    @FocusState private var focusedField: DailyGoalsField?
    @State private var paywallContext: ProPaywallContext?

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

            ProSettingsSection(paywallContext: $paywallContext)

            Section {
                NavigationLink {
                    SharingScreen()
                } label: {
                    Text("Sharing")
                }
            } footer: {
                Text("Shared totals are best-effort and may be delayed. They are not medical advice.")
            }

            MacroRingColorSettingsSection(
                proteinHex: $customProteinRingColor,
                carbHex: $customCarbRingColor,
                fatHex: $customFatRingColor,
                paywallContext: $paywallContext
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
        .navigationTitle("Settings")
        .inlineNavigationTitle()
        .onDisappear {
            dismissKeyboard($focusedField)
        }
        .sheet(item: $paywallContext) { context in
            ProPaywallSheet(context: context)
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
    @Binding var paywallContext: ProPaywallContext?

    var body: some View {
        let changedMetrics = changedMetrics

        Section {
            PaidFeatureGate(.customMacroRingColors) {
                ForEach(MacroMetric.allCases) { metric in
                    colorRow(for: metric)
                }

                if changedMetrics.count > 1 {
                    Button("Reset Ring Colors") {
                        for metric in changedMetrics {
                            setHex(defaultHex(for: metric), for: metric, reloadWidgets: false)
                        }
                        WidgetTimelineReloader.reloadMacroWidgets()
                    }
                }
            } locked: {
                Button {
                    paywallContext = .ringColors
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Customize Macro Ring Colors")
                                .foregroundStyle(Color.accentColor)
                            Text("Included with \(AppBrand.displayName) Pro")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Macro Ring Colors")
        } footer: {
            Text(
                entitlements.canUse(.customMacroRingColors)
                    ? "Color changes update the dashboard rings immediately."
                    : "Included with \(AppBrand.displayName) Pro"
            )
        }
    }

    private var changedMetrics: [MacroMetric] {
        MacroMetric.allCases.filter { hex(for: $0).wrappedValue != defaultHex(for: $0) }
    }

    private func colorRow(for metric: MacroMetric) -> some View {
        let title = "\(metric.title) Ring"
        let hex = hex(for: metric)
        let defaultHex = defaultHex(for: metric)
        let color = Color(hex: hex.wrappedValue) ?? .accentColor
        let isChanged = hex.wrappedValue != defaultHex

        return HStack(spacing: 16) {
            Button {
                presentColorPicker(for: metric)
            } label: {
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

                    Spacer()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .tint(color)

            if isChanged {
                Button("Reset") {
                    setHex(defaultHex, for: metric)
                }
                .buttonStyle(.glass)
            }
        }
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

    private func setHex(_ newHex: String, for metric: MacroMetric, reloadWidgets: Bool = true) {
        let hex = hex(for: metric)
        guard hex.wrappedValue != newHex else { return }

        hex.wrappedValue = newHex
        if reloadWidgets {
            WidgetTimelineReloader.reloadMacroWidgets()
        }
    }

    private func presentColorPicker(for metric: MacroMetric) {
        #if os(iOS)
        MacroRingColorPickerPresenter.present(for: metric, hex: hex(for: metric))
        #endif
    }
}

private struct SavedFoodsSection: View {
    private static let previewDisplayLimit = 5
    private static let previewFetchLimit = previewDisplayLimit + 1

    let title: String
    let emptyState: String
    let allFoodsDescriptor: FetchDescriptor<FoodItem>
    @Query private var foods: [FoodItem]

    init(title: String, emptyState: String, descriptor: FetchDescriptor<FoodItem>) {
        self.title = title
        self.emptyState = emptyState
        self.allFoodsDescriptor = descriptor

        var previewDescriptor = descriptor
        previewDescriptor.fetchLimit = Self.previewFetchLimit
        _foods = Query(previewDescriptor)
    }

    var body: some View {
        Section(title) {
            if foods.isEmpty {
                Text(emptyState)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(previewFoods) { food in
                    SavedFoodNavigationLink(food: food)
                }

                if hasMoreFoods {
                    NavigationLink {
                        SavedFoodsListScreen(
                            title: title,
                            emptyState: emptyState,
                            descriptor: allFoodsDescriptor
                        )
                    } label: {
                        Text("Show All")
                    }
                }
            }
        }
    }

    private var previewFoods: [FoodItem] {
        Array(foods.prefix(Self.previewDisplayLimit))
    }

    private var hasMoreFoods: Bool {
        foods.count > Self.previewDisplayLimit
    }
}

private struct SavedFoodsListScreen: View {
    let title: String
    let emptyState: String
    @Query private var foods: [FoodItem]

    init(title: String, emptyState: String, descriptor: FetchDescriptor<FoodItem>) {
        self.title = title
        self.emptyState = emptyState
        _foods = Query(descriptor)
    }

    var body: some View {
        List {
            if foods.isEmpty {
                Text(emptyState)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(foods) { food in
                    SavedFoodNavigationLink(food: food)
                }
            }
        }
        .navigationTitle(title)
        .inlineNavigationTitle()
    }
}

private struct SavedFoodNavigationLink: View {
    let food: FoodItem

    var body: some View {
        NavigationLink {
            ReusableFoodEditorScreen(food: food)
        } label: {
            SavedFoodRow(food: food)
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
