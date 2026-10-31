import SwiftUI

struct TutorialCaptionCard: View {
    @Environment(DashboardTutorial.self) private var tutorial
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled

    let step: DashboardTutorial.Step
    var onAction: (() -> Void)?

    private var message: String { step.message(nextMacro: tutorial.nextMacro) }
    private var prefersProminentAction: Bool { voiceOverEnabled || switchControlEnabled || reduceMotion }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title).font(.headline)
                Text(message).font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(message)
            .transition(.blurReplace)

            if step == .done {
                Button("Done", action: finish)
                    .buttonStyle(.glassProminent)
                    .frame(maxWidth: .infinity)
            } else {
                HStack {
                    Text("\(step.displayIndex) of \(DashboardTutorial.Step.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    actionButton
                    Button("Skip", action: finish)
                        .buttonStyle(.glass)
                }
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: message)
        .padding(16)
        .frame(maxWidth: 420)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .onChange(of: message, initial: true) {
            AccessibilityNotification.Announcement("\(step.title). \(message)").post()
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let onAction, let title = step.actionTitle(nextMacro: tutorial.nextMacro) {
            if prefersProminentAction {
                Button(title, action: onAction).buttonStyle(.glassProminent)
            } else {
                Button("Do it for me", action: onAction).buttonStyle(.plain).font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func finish() {
        tutorial.finish()
    }
}
