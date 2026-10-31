import SwiftData
import SwiftUI

struct TargetReviewScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [DailyGoals]
    @Binding var profile: BodyProfileDraft
    let onComplete: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var macroPreset: GoalMacroPreset = .balanced
    @State private var errorMessage: String?
    @State private var completionFeedbackToken = 0
    @ScaledMetric(relativeTo: .largeTitle) private var calorieFontSize: CGFloat = 48

    private var ageYears: Int {
        profile.age ?? 30
    }

    private var calculatedTarget: GoalCalorieTarget? {
        guard let heightCm = profile.heightCm, let weightKg = profile.weightKg else { return nil }
        guard
            let bmr = try? GoalCalculator.bmr(
                sex: profile.sex,
                ageYears: ageYears,
                heightCm: heightCm,
                weightKg: weightKg
            ),
            let tdee = try? GoalCalculator.tdee(bmr: bmr, activity: profile.activity)
        else { return nil }
        return try? GoalCalculator.targetCalories(tdee: tdee, offset: profile.offset, sex: profile.sex)
    }

    private var calculatedGoals: DailyGoalsDraft? {
        guard let calories = calculatedTarget?.calories else { return nil }
        return try? GoalCalculator.macroGrams(calories: calories, preset: macroPreset)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: OnboardingLayout.headerSpacing) {
                    OnboardingHeader(
                        symbol: "target", title: "Your targets", subtitle: "A starting point you can adjust anytime.")
                    targetContent
                }
                .padding(.horizontal, OnboardingLayout.horizontalInset)
                .padding(.vertical, OnboardingLayout.verticalPadding)
            }
            BottomPinnedActionBar(
                title: "Continue",
                systemImage: nil,
                isDisabled: calculatedGoals == nil,
                edgeFadeColor: PlatformColors.groupedBackground,
                action: saveTargets
            )
        }
        .background(PlatformColors.groupedBackground)
        .navigationTitle("")
        .inlineNavigationTitle()
        .errorBanner(message: $errorMessage)
        .sensoryFeedback(.success, trigger: completionFeedbackToken)
        .onAppear {
            if let savedProfile = try? BodyProfileRepository.activeProfile(modelContext: modelContext) {
                macroPreset = savedProfile.macroPreset
            }
        }
    }

    private var macroColumnLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: OnboardingLayout.cardSpacing))
            : AnyLayout(HStackLayout(spacing: 8))
    }

    @ViewBuilder
    private var targetContent: some View {
        VStack(spacing: 24) {
            if let calculatedTarget, let calculatedGoals {
                let proposedGoals = MacroGoalsSnapshot(
                    calorieGoal: calculatedGoals.calorieGoal,
                    proteinGoalGrams: calculatedGoals.proteinGoalGrams,
                    fatGoalGrams: calculatedGoals.fatGoalGrams,
                    carbGoalGrams: calculatedGoals.carbGoalGrams
                )
                VStack(spacing: 4) {
                    Text("Daily calorie target")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("\(Int(calculatedGoals.calorieGoal.rounded()))")
                        .font(.system(size: calorieFontSize, weight: .bold, design: .rounded))
                    Text("kcal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                macroColumnLayout {
                    ForEach(MacroMetric.allCases) { metric in
                        MacroSummaryColumnView(
                            metric: metric,
                            totals: .zero,
                            goals: proposedGoals,
                            titleStyle: .full,
                            style: .dashboardCard
                        )
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "Proposed goals: \(Int(calculatedGoals.calorieGoal)) calories, "
                        + "\(Int(calculatedGoals.proteinGoalGrams)) grams protein, "
                        + "\(Int(calculatedGoals.carbGoalGrams)) grams carbs, "
                        + "\(Int(calculatedGoals.fatGoalGrams)) grams fat"
                )

                Picker("Macro balance", selection: $macroPreset) {
                    ForEach([GoalMacroPreset.balanced, .highProtein, .lowCarb], id: \.self) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.menu)

                if calculatedTarget.isBelowSafeMinimum {
                    Label(
                        "This estimate was raised to a safe minimum of \(Int(calculatedTarget.calories)) kcal.",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Text("Targets are estimates, not medical advice. Check with a doctor before making health decisions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                NavigationLink {
                    GoalSetupScreen(
                        initialDraft: calculatedGoals,
                        bodyProfile: profile.makeProfile(preset: macroPreset),
                        onComplete: onComplete
                    )
                } label: {
                    Text("Adjust manually")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
            } else {
                ContentUnavailableView("Check your details", systemImage: "exclamationmark.circle")
            }
        }
    }

    private func saveTargets() {
        guard let draft = calculatedGoals, let activeGoals = DailyGoals.activeRecord(from: goals) else {
            errorMessage = "Unable to save your targets. Please try again."
            return
        }
        let bodyProfile = profile.makeProfile(preset: macroPreset)
        do {
            try BodyProfileRepository(modelContext: modelContext).save(bodyProfile, operation: "Save body profile")
            try DailyGoalsRepository(modelContext: modelContext)
                .saveGoals(from: draft, to: activeGoals, operation: "Save calculated goals")
            errorMessage = nil
            completionFeedbackToken += 1
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
