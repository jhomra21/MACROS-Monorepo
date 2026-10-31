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
    var onAction: (() -> Void)?

    private var message: String { step.message(nextMacro: tutorial.nextMacro) }
    private var prefersProminentAction: Bool { voiceOverEnabled || switchControlEnabled || reduceMotion }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(step.title).font(.title3.weight(.semibold))
                Text(message).font(.body).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(message)
            .transition(.blurReplace)

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
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: message)
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
    }

    @ViewBuilder
    private var actionButton: some View {
        if let onAction, let title = step.actionTitle(nextMacro: tutorial.nextMacro) {
            if prefersProminentAction {
                Button(title, action: onAction).buttonStyle(.borderedProminent).controlSize(.small)
            } else {
                Button("Do it for me", action: onAction).buttonStyle(.bordered).controlSize(.small)
            }
        }
    }
}

struct TutorialDoneCard: View {
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 64
    @AccessibilityFocusState private var isDoneFocused: Bool
    @State private var appeared = false

    let onDone: () -> Void

    private let recap: [(symbol: String, text: String)] = [
        ("arrow.left", "Swipe left for Sharing"),
        ("arrow.right", "Swipe right for past days"),
        ("circle.circle", "Tap the rings for details")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: iconSize))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.green)
                .symbolEffect(.drawOn, isActive: !appeared)
                .accessibilityHidden(true)
            Text("You're all set")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(recap, id: \.text) { row in
                    HStack(spacing: 12) {
                        Image(systemName: row.symbol)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tint)
                            .frame(width: 28, height: 28)
                            .background(.tint.opacity(0.15), in: Circle())
                            .accessibilityHidden(true)
                        Text(row.text).font(.subheadline)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 20)

            Text("Log your first food with Camera or Add Food.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)

            Button(action: onDone) {
                Text("Done").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .accessibilityFocused($isDoneFocused)
        }
        .tutorialCardStyle(padding: 24, maxWidth: 360)
        .accessibilityElement(children: .contain)
        .sensoryFeedback(.success, trigger: appeared) { _, new in new }
        .onAppear {
            appeared = true
            isDoneFocused = true
            AccessibilityNotification.Announcement(
                "You're all set. " + recap.map(\.text).joined(separator: ". ")
            ).post()
        }
    }
}
