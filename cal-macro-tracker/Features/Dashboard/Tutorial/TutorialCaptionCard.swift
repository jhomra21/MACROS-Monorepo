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
        .padding(step == .done ? 12 : 22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .dynamicTypeSize(dynamicTypeSize.isAccessibilitySize ? ...DynamicTypeSize.xxxLarge : ...DynamicTypeSize.accessibility5)
        .onChange(of: message, initial: true) {
            guard step != .done else { return }
            AccessibilityNotification.Announcement("\(step.title). \(message)").post()
        }
    }

    private var doneContent: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36, weight: .regular))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .green)
                .symbolEffect(.drawOn, isActive: !didAppear)
                .accessibilityHidden(true)
            Text(step.title)
                .font(.title3.weight(.bold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 10) {
                Label("Swipe left for Sharing", systemImage: "hand.point.left")
                Label("Swipe right for past days", systemImage: "hand.point.right")
                Label("Tap the rings for details", systemImage: "hand.tap")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .onAppear { didAppear = true }
    }
}

struct TutorialActionBar: View {
    @Environment(DashboardTutorial.self) private var tutorial
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .opacity(hasAction ? 1 : 0)
                .disabled(!hasAction)
                .accessibilityHidden(!hasAction)
                .accessibilityFocused($isDoneFocused)

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
            .opacity(step == .done ? 0 : 1)
            .disabled(step == .done)
            .accessibilityHidden(step == .done)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 36)
        .background(.regularMaterial)
        .dynamicTypeSize(dynamicTypeSize.isAccessibilitySize ? ...DynamicTypeSize.xxxLarge : ...DynamicTypeSize.accessibility5)
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
}
