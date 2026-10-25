import SwiftData
import SwiftUI

struct BodyProfileDraft {
    var sex: GoalSex = .unspecified
    var ageText = "30"
    var heightText = ""
    var heightInchesText = ""
    var weightText = ""
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

    var heightCm: Double? {
        guard let height = Self.number(from: heightText) else { return nil }
        if unitSystem == .metric { return height > 0 ? height : nil }
        guard let feet = Int(exactly: height), let inches = Self.number(from: heightInchesText) else { return nil }
        return try? GoalCalculator.cm(fromFeet: feet, inches: inches)
    }

    var weightKg: Double? {
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
        if let heightCm = profile.heightCm {
            if unitSystem == .metric {
                heightText = String(Int(heightCm.rounded()))
            } else {
                let (feet, inches) = GoalCalculator.feetAndInches(fromCm: heightCm)
                heightText = String(feet)
                heightInchesText = String(Int(inches))
            }
        }
        if let weightKg = profile.weightKg {
            weightText = unitSystem == .metric ? String(format: "%.1f", weightKg) : String(GoalCalculator.pounds(fromKg: weightKg))
        }
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
        if let weightKg, newSystem == .imperial {
            weightText = String(GoalCalculator.pounds(fromKg: weightKg))
        } else if let weightKg, newSystem == .metric {
            weightText = String(format: "%.1f", weightKg)
        }
        if let heightCm, newSystem == .imperial {
            let (feet, inches) = GoalCalculator.feetAndInches(fromCm: heightCm)
            heightText = String(feet)
            heightInchesText = String(Int(inches))
        } else if let heightCm, newSystem == .metric {
            heightText = String(Int(heightCm.rounded()))
            heightInchesText = ""
        }
        unitSystem = newSystem
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

    private enum ProfileField: Hashable {
        case age
        case height
        case weight
    }

    private var isValid: Bool {
        guard
            let age = profile.age,
            let height = profile.heightCm,
            let weight = profile.weightKg
        else { return false }
        return (1...120).contains(age) && height.isFinite && weight.isFinite && height > 0 && weight > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    profileInputRows
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } header: {
                    Text("About you")
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
                action: {
                    dismissKeyboard($focusedField)
                    onContinue()
                }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .navigationTitle("About you")
        .inlineNavigationTitle()
        .scrollDismissesKeyboard(.interactively)
        .keyboardNavigationToolbar(focusedField: $focusedField, fields: [.age, .height, .weight])
    }

    @ViewBuilder
    private var profileInputRows: some View {
        let rows = VStack(spacing: 12) {
            Picker("Sex", selection: $profile.sex) {
                ForEach(GoalSex.allCases, id: \.self) { sex in
                    Text(sex.title).tag(sex)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Sex")
            .padding(12)
            .appGlassRoundedRect(cornerRadius: 18)

            profileNumericRow("Age", value: $profile.ageText, suffix: "years", field: .age)
            if profile.ageText.isEmpty {
                Text("Age is unknown. We’ll use 30 for this estimate.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if profile.unitSystem == .metric {
                profileNumericRow("Height", value: $profile.heightText, suffix: "cm", field: .height)
            } else {
                HStack {
                    Text("Height")
                    Spacer()
                    AppNumericTextField("Feet", text: $profile.heightText, focusedField: $focusedField, field: .height)
                        .frame(width: 58)
                        .accessibilityLabel("Height, feet")
                    Text("ft").foregroundStyle(.secondary)
                    AppNumericTextField(
                        "Inches", text: $profile.heightInchesText, focusedField: $focusedField, field: .height
                    )
                    .frame(width: 58)
                    .accessibilityLabel("Height, inches")
                    Text("in").foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .frame(height: 58)
                .appGlassRoundedRect(cornerRadius: 18)
            }
            profileNumericRow(
                "Weight",
                value: $profile.weightText,
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
            .appGlassRoundedRect(cornerRadius: 18)
        }
        if #available(iOS 26, macOS 26, *) {
            GlassEffectContainer(spacing: 12) {
                rows
            }
        } else {
            rows
        }
    }

    private func profileNumericRow(
        _ title: String,
        value: Binding<String>,
        suffix: String,
        field: ProfileField
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            AppNumericTextField(title, text: value, focusedField: $focusedField, field: field)
                .frame(width: 100)
            Text(suffix).foregroundStyle(.secondary).frame(width: 46, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .padding(.horizontal, 16)
        .frame(height: 58)
        .appGlassRoundedRect(cornerRadius: 18)
        .accessibilityLabel(title)
    }

    private func rateLabel(_ rate: Double) -> String {
        let amount = profile.unitSystem == .metric ? rate : rate * 2.20462
        return "\(amount.formatted(.number.precision(.fractionLength(1)))) \(profile.unitSystem == .metric ? "kg" : "lb")/week"
    }
}
