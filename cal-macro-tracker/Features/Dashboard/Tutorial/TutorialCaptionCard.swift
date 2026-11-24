import SwiftUI

struct TutorialCaptionCard: View {
    @Environment(DashboardTutorial.self) private var tutorial
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let step: DashboardTutorial.Step

    private var message: String { step.message(nextMacro: tutorial.nextMacro) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Step \(step.displayIndex) of \(DashboardTutorial.Step.count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
                .accessibilityLabel("Step \(step.displayIndex) of \(DashboardTutorial.Step.count)")
            Text(step.title)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 420, alignment: .leading)
        .padding(22)
        .background(PlatformColors.cardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .onChange(of: message, initial: true) {
            AccessibilityNotification.Announcement("\(step.title). \(message)").post()
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: step)
    }
}

struct TutorialActionBar: View {
    @Environment(DashboardTutorial.self) private var tutorial

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
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .opacity(hasAction ? 1 : 0)
                .disabled(!hasAction)
                .accessibilityHidden(!hasAction)

            HStack(spacing: 12) {
                Button("Skip step", action: onSkipStep)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                Button("Skip tutorial", action: onSkipTutorial)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 36)
        .background(.regularMaterial)
    }

    private var actionTitle: String {
        step.actionTitle(nextMacro: tutorial.nextMacro) ?? " "
    }
}
