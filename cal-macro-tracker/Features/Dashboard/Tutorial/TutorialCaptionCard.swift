import SwiftUI

struct TutorialCaptionCard: View {
    @Environment(DashboardTutorial.self) private var tutorial
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isDoneFocused: Bool
    @State private var didAppear = false

    let step: DashboardTutorial.Step
    let onDone: () -> Void

    private var message: String { step.message(nextMacro: tutorial.nextMacro) }

    var body: some View {
        Group {
            if step == .done {
                doneContent
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity))
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
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: step == .done ? .contain : .combine)
        .accessibilityIdentifier(step == .done ? "tutorial.done.card" : "tutorial.caption")
        .onChange(of: step, initial: true) {
            if step == .done { isDoneFocused = true }
        }
        .onChange(of: message, initial: true) {
            guard step != .done else { return }
            AccessibilityNotification.Announcement("\(step.title). \(message)").post()
        }
    }

    private var doneContent: some View {
        VStack(spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    doneDetails
                }
                .scrollIndicators(.hidden)
            } else {
                doneDetails
            }

            AppAccentActionButton(
                title: "Done",
                systemImage: "checkmark",
                isCompact: false,
                action: onDone
            )
            .accessibilityLabel("Done")
            .accessibilityIdentifier("tutorial.done.button")
            .accessibilityFocused($isDoneFocused)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 60)
        }
        .frame(maxWidth: .infinity)
        .onAppear { didAppear = true }
    }

    private var doneDetails: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28, weight: .regular))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .green)
                .symbolEffect(.drawOn, isActive: !didAppear)
                .accessibilityHidden(true)
            Text(step.title)
                .font(.title3.bold())
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 10) {
                recapRow("Swipe left for Sharing", systemImage: "hand.point.left")
                recapRow("Swipe right for past days", systemImage: "hand.point.right")
                recapRow("Tap the rings for details", systemImage: "hand.tap")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func recapRow(_ title: String, systemImage: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: systemImage)
                .frame(width: 24, alignment: .center)
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
