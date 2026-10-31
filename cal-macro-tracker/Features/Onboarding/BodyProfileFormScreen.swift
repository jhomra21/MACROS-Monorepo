import SwiftData
import SwiftUI

struct BodyProfileDraft {
    var sex: GoalSex = .unspecified
    var ageText = "30"
    private(set) var heightText = ""
    private(set) var heightInchesText = ""
    private(set) var weightText = ""
    /// Canonical metric measurements at full precision. Text is an editing buffer; it never feeds back into these.
    private(set) var heightCm: Double?
    private(set) var weightKg: Double?
    var unitSystem: GoalUnitSystem = .metric
    var activity: GoalActivityLevel = .moderate
    var goalDirection = GoalDirection.maintain {
        didSet {
            if let highestPace = goalDirection.weeklyRates.last {
                weeklyRate = min(weeklyRate, highestPace)
            }
        }
    }
    var weeklyRate = 0.5

    var offset: Double {
        switch goalDirection {
        case .lose: -weeklyRate * 1_000
        case .maintain: 0
        case .gain: min(500, weeklyRate * 1_000)
        }
    }

    var age: Int? {
        switch NumericText.state(for: ageText) {
        case .empty: 30
        case let .valid(value): Int(exactly: value)
        case .invalid: nil
        }
    }

    private var measuredHeightCm: Double? {
        guard let height = Self.number(from: heightText) else { return nil }
        if unitSystem == .metric { return height > 0 ? height : nil }
        guard let feet = Int(exactly: height), let inches = Self.number(from: heightInchesText) else { return nil }
        return try? GoalCalculator.cm(fromFeet: feet, inches: inches)
    }

    private var measuredWeightKg: Double? {
        guard let weight = Self.number(from: weightText), weight > 0 else { return nil }
        return unitSystem == .metric ? weight : try? GoalCalculator.kg(fromPounds: weight)
    }

    private static func number(from text: String) -> Double? {
        guard case let .valid(value) = NumericText.state(for: text) else { return nil }
        return value
    }

    init(profile: BodyProfile? = nil) {
        guard let profile else { return }
        sex = profile.sex
        if let birthYear = profile.birthYear {
            ageText = String(max(1, Calendar.current.component(.year, from: .now) - birthYear))
        }
        unitSystem = profile.unitSystem
        heightCm = profile.heightCm
        weightKg = profile.weightKg
        refreshDisplayText()
        activity = profile.activityLevel
        let offset = profile.goalCalorieOffset
        goalDirection = offset < 0 ? .lose : offset > 0 ? .gain : .maintain
        weeklyRate = min(0.75, max(0.25, abs(offset) / 1_000))
    }

    func makeProfile(preset: GoalMacroPreset) -> BodyProfile {
        BodyProfile(
            sex: sex,
            birthYear: age.map { Calendar.current.component(.year, from: .now) - $0 },
            heightCm: heightCm,
            weightKg: weightKg,
            activityLevel: activity,
            goalCalorieOffset: offset,
            macroPreset: preset,
            unitSystem: unitSystem
        )
    }

    mutating func changeUnitSystem(to newSystem: GoalUnitSystem) {
        guard newSystem != unitSystem else { return }
        unitSystem = newSystem
        refreshDisplayText()
    }

    mutating func setHeightText(_ text: String) {
        heightText = text
        heightCm = measuredHeightCm
    }

    mutating func setHeightInchesText(_ text: String) {
        heightInchesText = text
        heightCm = measuredHeightCm
    }

    mutating func setWeightText(_ text: String) {
        weightText = text
        weightKg = measuredWeightKg
    }

    /// Rebuilds editable text from the canonical metric values. Rounding happens here, for display only.
    private mutating func refreshDisplayText() {
        if let heightCm {
            (heightText, heightInchesText) = Self.heightTexts(cm: heightCm, unit: unitSystem)
        }
        if let weightKg {
            weightText = Self.weightText(kg: weightKg, unit: unitSystem)
        }
    }

    private static func heightTexts(cm: Double, unit: GoalUnitSystem) -> (String, String) {
        guard unit == .imperial else { return (NumericText.editingDisplay(for: cm.rounded()), "") }
        let (feet, inches) = GoalCalculator.feetAndInches(fromCm: cm)
        return (NumericText.editingDisplay(for: Double(feet)), NumericText.editingDisplay(for: inches))
    }

    private static func weightText(kg: Double, unit: GoalUnitSystem) -> String {
        guard unit == .imperial else { return NumericText.editingDisplay(for: (kg * 10).rounded() / 10) }
        return NumericText.editingDisplay(for: GoalCalculator.pounds(fromKg: kg).rounded())
    }
}

enum GoalDirection: String, CaseIterable, Identifiable {
    case lose
    case maintain
    case gain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lose: "Lose"
        case .maintain: "Maintain"
        case .gain: "Gain"
        }
    }

    /// Weekly paces in kg. Gain stops at 0.5 kg/week because +750 kcal/day is above the +500 offset ceiling.
    var weeklyRates: [Double] {
        switch self {
        case .lose: [0.25, 0.5, 0.75]
        case .maintain: []
        case .gain: [0.25, 0.5]
        }
    }
}

struct BodyProfileFormScreen: View {
    @Binding var profile: BodyProfileDraft
    let onContinue: () -> Void
    @FocusState private var focusedField: ProfileField?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var rowMinHeight: CGFloat = 58

    private enum ProfileField: Hashable {
        case age
        case height
        case heightFeet
        case heightInches
        case weight
    }

    private var keyboardFields: [ProfileField] {
        profile.unitSystem == .metric
            ? [.age, .height, .weight]
            : [.age, .heightFeet, .heightInches, .weight]
    }

    private var isValid: Bool {
        guard
            let age = profile.age,
            let height = profile.heightCm,
            let weight = profile.weightKg
        else { return false }
        return (1...120).contains(age) && height.isFinite && weight.isFinite && height > 0 && weight > 0
    }

    /// Label-over-field stacking at accessibility sizes so fixed-width fields never clip.
    private var rowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout())
    }

    private var heightBinding: Binding<String> {
        Binding(get: { profile.heightText }, set: { profile.setHeightText($0) })
    }

    private var heightInchesBinding: Binding<String> {
        Binding(get: { profile.heightInchesText }, set: { profile.setHeightInchesText($0) })
    }

    private var weightBinding: Binding<String> {
        Binding(get: { profile.weightText }, set: { profile.setWeightText($0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    OnboardingHeader(
                        symbol: "person.crop.circle", title: "About you",
                        subtitle: "Get a starting point based on your body and routine."
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(
                        EdgeInsets(
                            top: 0, leading: OnboardingLayout.horizontalInset,
                            bottom: OnboardingLayout.headerSpacing - 8, trailing: OnboardingLayout.horizontalInset))

                    profileInputRows
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(
                            EdgeInsets(
                                top: 8, leading: OnboardingLayout.horizontalInset, bottom: 8,
                                trailing: OnboardingLayout.horizontalInset))
                }

                Section("Activity") {
                    Picker("Activity level", selection: $profile.activity) {
                        ForEach(GoalActivityLevel.allCases, id: \.self) { activity in
                            VStack(alignment: .leading) {
                                Text(activity.title)
                                Text(activity.description).font(.caption).foregroundStyle(.secondary)
                            }
                            .tag(activity)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Activity level, \(profile.activity.title)")
                    Text(profile.activity.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Your goal") {
                    Picker("Direction", selection: $profile.goalDirection) {
                        ForEach(GoalDirection.allCases) { direction in
                            Text(direction.title).tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Goal")
                    if profile.goalDirection != .maintain {
                        Picker("Weekly pace", selection: $profile.weeklyRate) {
                            ForEach(profile.goalDirection.weeklyRates, id: \.self) { rate in
                                Text(rateLabel(rate)).tag(rate)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            BottomPinnedActionBar(
                title: "Review targets", systemImage: nil, isDisabled: !isValid,
                edgeFadeColor: PlatformColors.groupedBackground,
                action: {
                    dismissKeyboard($focusedField)
                    onContinue()
                }
            )
        }
        .background(PlatformColors.groupedBackground)
        .navigationTitle("")
        .inlineNavigationTitle()
        .scrollDismissesKeyboard(.interactively)
        .keyboardNavigationToolbar(focusedField: $focusedField, fields: keyboardFields)
    }

    private var profileInputRows: some View {
        VStack(spacing: 12) {
            Picker("Sex", selection: $profile.sex) {
                ForEach(GoalSex.allCases, id: \.self) { sex in
                    Text(sex.title).tag(sex)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Sex")
            .padding(12)
            .appCardBackground(cornerRadius: 20)

            profileNumericRow("Age", value: $profile.ageText, suffix: "years", field: .age)
            if profile.ageText.isEmpty {
                Text("Age is unknown. We’ll use 30 for this estimate.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if profile.unitSystem == .metric {
                profileNumericRow("Height", value: heightBinding, suffix: "cm", field: .height)
            } else {
                rowLayout {
                    Text("Height")
                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer()
                    }
                    HStack {
                        AppNumericTextField("Feet", text: heightBinding, focusedField: $focusedField, field: .heightFeet)
                            .frame(width: 58)
                            .accessibilityLabel("Height, feet")
                        Text("ft").foregroundStyle(.secondary)
                        AppNumericTextField(
                            "Inches", text: heightInchesBinding, focusedField: $focusedField, field: .heightInches
                        )
                        .frame(width: 58)
                        .accessibilityLabel("Height, inches")
                        Text("in").foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: rowMinHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCardBackground(cornerRadius: 20)
            }
            profileNumericRow(
                "Weight",
                value: weightBinding,
                suffix: profile.unitSystem == .metric ? "kg" : "lb",
                field: .weight
            )
            Picker(
                "Units",
                selection: Binding(
                    get: { profile.unitSystem },
                    set: { profile.changeUnitSystem(to: $0) }
                )
            ) {
                Text("Metric").tag(GoalUnitSystem.metric)
                Text("Imperial").tag(GoalUnitSystem.imperial)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Units")
            .padding(12)
            .appCardBackground(cornerRadius: 20)
        }
    }

    private func profileNumericRow(
        _ title: String,
        value: Binding<String>,
        suffix: String,
        field: ProfileField
    ) -> some View {
        rowLayout {
            Text(title)
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }
            HStack {
                AppNumericTextField(title, text: value, focusedField: $focusedField, field: field)
                    .frame(width: 100)
                Text(suffix).foregroundStyle(.secondary).frame(minWidth: 46, alignment: .leading)
            }
        }
        .accessibilityElement(children: .contain)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: rowMinHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardBackground(cornerRadius: 20)
        .accessibilityLabel(title)
    }

    private func rateLabel(_ rate: Double) -> String {
        let amount = profile.unitSystem == .metric ? rate : GoalCalculator.pounds(fromKg: rate)
        return "\(amount.formatted(.number.precision(.fractionLength(1)))) \(profile.unitSystem == .metric ? "kg" : "lb")/week"
    }
}
