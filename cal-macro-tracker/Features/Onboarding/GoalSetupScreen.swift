import SwiftData
import SwiftUI

struct GoalSetupScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [DailyGoals]
    @FocusState private var focusedField: DailyGoalsField?

    let onComplete: () -> Void

    @State private var numericText = DailyGoalsNumericText()
    @State private var hasLoadedGoals = false
    @State private var errorMessage: String?
    @State private var continueFeedbackToken = 0

    private let fieldOrder: [DailyGoalsField] = [.calories, .protein, .carbs, .fat]

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
            .errorBanner(message: $errorMessage)
            .scrollDismissesKeyboard(.interactively)
            .keyboardNavigationToolbar(focusedField: $focusedField, fields: fieldOrder)
            .sensoryFeedback(.success, trigger: continueFeedbackToken)
            .onAppear(perform: loadGoalsIfNeeded)
    }

    private var content: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 24)

            header

            goalsList

            Spacer()

            BottomPinnedActionBar(
                title: "Continue",
                systemImage: nil,
                isDisabled: !canContinue,
                topPadding: 0,
                action: saveGoals
            )
            .padding(.bottom, 8)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("Macros")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text("Set up your targets")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var goalsList: some View {
        if #available(iOS 26, macOS 26, *) {
            GlassEffectContainer(spacing: 14) {
                goalRows
            }
        } else {
            goalRows
        }
    }

    private var goalRows: some View {
        VStack(spacing: 14) {
            ForEach(fieldOrder, id: \.self) { field in
                goalRow(field)
            }
        }
        .padding(.horizontal, 16)
    }

    private func goalRow(_ field: DailyGoalsField) -> some View {
        HStack(spacing: 16) {
            Text(title(for: field))
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

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
        .padding(.horizontal, 18)
        .frame(height: 62)
        .appGlassRoundedRect(cornerRadius: 20)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = field
        }
    }

    private func binding(for field: DailyGoalsField) -> Binding<String> {
        Binding(
            get: { numericText[field] },
            set: { numericText[field] = $0 }
        )
    }

    private func title(for field: DailyGoalsField) -> String {
        field == .fat ? "Fats" : field.title
    }

    private func loadGoalsIfNeeded() {
        guard !hasLoadedGoals, let activeGoals else { return }
        numericText = DailyGoalsNumericText(goals: activeGoals)
        hasLoadedGoals = true
    }

    private func saveGoals() {
        guard let activeGoals, let finalizedDraft = numericText.finalizedDraft else {
            errorMessage = "Please fix invalid numeric values before continuing."
            return
        }

        dismissKeyboard($focusedField)

        do {
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
