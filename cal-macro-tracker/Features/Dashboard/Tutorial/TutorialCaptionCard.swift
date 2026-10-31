import SwiftUI

extension View {
    /// Solid and elevated rather than glass so it stays readable on the dimmed screen in both appearances.
    func tutorialCardStyle(padding: CGFloat, maxWidth: CGFloat) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: maxWidth)
            .background(PlatformColors.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
    }
}

struct TutorialCaptionCard: View {
    @Environment(DashboardTutorial.self) private var tutorial
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let step: DashboardTutorial.Step
    let onAction: () -> Void

    private var message: String { step.message(nextMacro: tutorial.nextMacro) }
    private var prefersProminentAction: Bool { voiceOverEnabled || switchControlEnabled || reduceMotion }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(step.title).font(.title3.weight(.semibold))
                Text(message).font(.body).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    progress
                    actionButton
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    skipButton
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: 12) {
                    progress
                    Spacer()
                    skipButton
                    actionButton
                }
            }
        }
        .tutorialCardStyle(padding: 20, maxWidth: 420)
        .accessibilityElement(children: .contain)
        .onChange(of: message, initial: true) {
            AccessibilityNotification.Announcement("\(step.title). \(message)").post()
        }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(1...DashboardTutorial.Step.count, id: \.self) { index in
                Capsule()
                    .fill(index == step.displayIndex ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .frame(width: index == step.displayIndex ? 18 : 6, height: 6)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: step.displayIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.displayIndex) of \(DashboardTutorial.Step.count)")
    }

    private var skipButton: some View {
        Button("Skip") { tutorial.finish() }
            .buttonStyle(.plain)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var actionButton: some View {
        if let title = step.actionTitle(nextMacro: tutorial.nextMacro) {
            Group {
                if prefersProminentAction {
                    Button(title, action: onAction).buttonStyle(.borderedProminent)
                } else {
                    Button("Do it for me", action: onAction).buttonStyle(.bordered)
                }
            }
            .controlSize(.small)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
    }
}

struct TutorialDoneCard: View {
    @ScaledMetric(relativeTo: .largeTitle) private var checkSize: CGFloat = 56
    @AccessibilityFocusState private var isDoneFocused: Bool
    @State private var appeared = false

    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: checkSize, weight: .regular))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .green)
                .symbolEffect(.drawOn, isActive: !appeared)
                .accessibilityHidden(true)
            Text(DashboardTutorial.Step.done.title)
                .font(.title2.bold())
                .padding(.top, 14)
            Text(DashboardTutorial.Step.done.message(nextMacro: nil))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            VStack(spacing: 12) {
                Label("Swipe left for Sharing", systemImage: "hand.point.left")
                Label("Swipe right for past days", systemImage: "hand.point.right")
                Label("Tap the rings for details", systemImage: "hand.tap")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, 24)

            AppAccentActionButton(title: "Done", systemImage: nil, isCompact: false, action: onDone)
                .padding(.top, 28)
                .accessibilityFocused($isDoneFocused)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: 360)
        .background(PlatformColors.cardBackground, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
        .accessibilityElement(children: .contain)
        .sensoryFeedback(.success, trigger: appeared) { _, new in new }
        .onAppear {
            appeared = true
            isDoneFocused = true
        }
    }

}
