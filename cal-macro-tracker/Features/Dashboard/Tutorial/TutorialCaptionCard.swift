import SwiftUI

struct TutorialCaptionCard: View {
    @Environment(DashboardTutorial.self) private var tutorial
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let step: DashboardTutorial.Step

    private var message: String { step.message(nextMacro: tutorial.nextMacro) }

    var body: some View {
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
        .frame(maxWidth: 420, alignment: .leading)
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tutorial.caption")
        .onChange(of: message, initial: true) {
            AccessibilityNotification.Announcement("\(step.title). \(message)").post()
        }
    }
}
