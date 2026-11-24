import SwiftUI

struct TutorialCaptionCard: View {
    @Environment(DashboardTutorial.self) private var tutorial
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var didAppear = false

    let step: DashboardTutorial.Step

    private var message: String { step.message(nextMacro: tutorial.nextMacro) }

    var body: some View {
        Group {
            if step == .done {
                doneContent
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        Text("Step \(step.displayIndex) of \(DashboardTutorial.Step.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Step \(step.displayIndex) of \(DashboardTutorial.Step.count)")
                    }
                    Text(step.title)
                        .font(.title2.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
        .padding(step == .done ? 8 : 22)
        .background(PlatformColors.cardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .onChange(of: message, initial: true) {
            guard step != .done else { return }
            AccessibilityNotification.Announcement("\(step.title). \(message)").post()
        }
    }

    private var doneContent: some View {
        VStack(spacing: 2) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28, weight: .regular))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .green)
                .symbolEffect(.drawOn, isActive: !didAppear)
                .accessibilityHidden(true)
            Text(step.title)
                .font(.subheadline.weight(.bold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 4) {
                Label("Swipe left for Sharing", systemImage: "hand.point.left")
                Label("Swipe right for past days", systemImage: "hand.point.right")
                Label("Tap the rings for details", systemImage: "hand.tap")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .onAppear { didAppear = true }
    }
}

struct TutorialActionBar: View {
    @Environment(DashboardTutorial.self) private var tutorial
    @AccessibilityFocusState private var isDoneFocused: Bool
    @State private var didShowDone = false

    let step: DashboardTutorial.Step
    let onAction: () -> Void
    let onSkipStep: () -> Void
    let onSkipTutorial: () -> Void

    var body: some View {
        let hasAction = step.actionTitle(nextMacro: tutorial.nextMacro) != nil
        VStack(spacing: 10) {
            Button(actionTitle, action: onAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .opacity(hasAction ? 1 : 0)
                .disabled(!hasAction)
                .accessibilityHidden(!hasAction)
                .accessibilityFocused($isDoneFocused)

            if step != .done {
                HStack(spacing: 12) {
                    skipStepButton
                    skipTutorialButton
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 36)
        .background(.regularMaterial)
        .sensoryFeedback(.success, trigger: step == .done) { _, newValue in newValue }
        .onChange(of: step, initial: true) {
            guard step == .done, !didShowDone else { return }
            didShowDone = true
            isDoneFocused = true
        }
    }

    private var actionTitle: String {
        step.actionTitle(nextMacro: tutorial.nextMacro) ?? " "
    }

    private var skipStepButton: some View {
        Button("Skip step", action: onSkipStep)
            .buttonStyle(.bordered)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
    }

    private var skipTutorialButton: some View {
        Button("Skip tutorial", action: onSkipTutorial)
            .buttonStyle(.bordered)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
    }
}
