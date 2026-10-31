import SwiftData
import SwiftUI

struct GoalSetupScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [DailyGoals]
    @FocusState private var focusedField: DailyGoalsField?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var rowMinHeight: CGFloat = 62

    let onComplete: () -> Void
    let initialDraft: DailyGoalsDraft?
    let bodyProfile: BodyProfile?

    @State private var numericText: DailyGoalsNumericText
    @State private var hasLoadedGoals = false
    @State private var errorMessage: String?
    @State private var continueFeedbackToken = 0

    private let fieldOrder: [DailyGoalsField] = [.calories, .protein, .carbs, .fat]

    init(
        initialDraft: DailyGoalsDraft? = nil,
        bodyProfile: BodyProfile? = nil,
        onComplete: @escaping () -> Void
    ) {
        self.initialDraft = initialDraft
        self.bodyProfile = bodyProfile
        self.onComplete = onComplete
        var numericText = DailyGoalsNumericText()
        if let initialDraft {
            numericText.calories = NumericText.editingDisplay(for: initialDraft.calorieGoal)
            numericText.protein = NumericText.editingDisplay(for: initialDraft.proteinGoalGrams)
            numericText.carbs = NumericText.editingDisplay(for: initialDraft.carbGoalGrams)
            numericText.fat = NumericText.editingDisplay(for: initialDraft.fatGoalGrams)
        }
        _numericText = State(initialValue: numericText)
    }

    private var activeGoals: DailyGoals? {
        DailyGoals.activeRecord(from: goals)
    }

    private var goalsRepository: DailyGoalsRepository {
        DailyGoalsRepository(modelContext: modelContext)
    }

    private var canContinue: Bool {
        numericText.finalizedDraft != nil
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PlatformColors.groupedBackground)
            .navigationTitle("")
            .inlineNavigationTitle()
            .errorBanner(message: $errorMessage)
            .scrollDismissesKeyboard(.interactively)
            .keyboardNavigationToolbar(focusedField: $focusedField, fields: fieldOrder)
            .sensoryFeedback(.success, trigger: continueFeedbackToken)
            .onAppear(perform: loadGoalsIfNeeded)
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: OnboardingLayout.headerSpacing) {
                    OnboardingHeader(
                        symbol: "slider.horizontal.3", title: "Set your targets",
                        subtitle: "Enter your daily calorie and macro goals.")
                    goalRows
                }
                .padding(.horizontal, OnboardingLayout.horizontalInset)
                .padding(.vertical, OnboardingLayout.verticalPadding)
            }
            .scrollBounceBehavior(.basedOnSize)

            BottomPinnedActionBar(
                title: "Continue",
                systemImage: nil,
                isDisabled: !canContinue,
                edgeFadeColor: PlatformColors.groupedBackground,
                action: saveGoals
            )
        }
    }

    private var goalRows: some View {
        VStack(spacing: OnboardingLayout.cardSpacing) {
            ForEach(fieldOrder, id: \.self) { field in
                goalRow(field)
            }
        }
    }

    private func goalRow(_ field: DailyGoalsField) -> some View {
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 16))

        return layout {
            Button(field.title) {
                focusedField = field
            }
            .buttonStyle(.plain)
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())

            HStack(spacing: 8) {
                AppNumericTextField(
                    field.title,
                    text: binding(for: field),
                    focusedField: $focusedField,
                    field: field
                )
                .frame(width: 96)

                Text(field.suffix)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .leading)
            }
        }
        .padding(16)
        .frame(minHeight: rowMinHeight)
        .appCardBackground(cornerRadius: 20)
    }

    private func binding(for field: DailyGoalsField) -> Binding<String> {
        Binding(
            get: { numericText[field] },
            set: { numericText[field] = $0 }
        )
    }

    private func loadGoalsIfNeeded() {
        guard !hasLoadedGoals else { return }
        if initialDraft == nil, let activeGoals {
            numericText = DailyGoalsNumericText(goals: activeGoals)
        }
        hasLoadedGoals = true
    }

    private func saveGoals() {
        guard let activeGoals, let finalizedDraft = numericText.finalizedDraft else {
            errorMessage = "Please fix invalid numeric values before continuing."
            return
        }

        dismissKeyboard($focusedField)

        do {
            try BodyProfileRepository(modelContext: modelContext)
                .save(bodyProfile ?? BodyProfile(), operation: "Save body profile")
            try goalsRepository.saveGoals(from: finalizedDraft, to: activeGoals, operation: "Complete goal setup")
            errorMessage = nil
            continueFeedbackToken += 1
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }
}
