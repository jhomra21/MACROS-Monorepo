import SwiftUI

struct LoggingStreakLine: View {
    let today: CalendarDay
    let onOpenInsights: () -> Void

    var body: some View {
        LoggingStreakReader(today: today) { summary, earnedBadges in
            if summary.current > 1 {
                Button(action: onOpenInsights) {
                    HStack(spacing: 4) {
                        if !earnedBadges.isEmpty {
                            Image(systemName: "rosette")
                                .accessibilityHidden(true)
                        }
                        Text("\(summary.current)-day logging streak")
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .imageScale(.small)
                            .accessibilityHidden(true)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(summary.current)-day logging streak. Open Insights.")
            }
        }
    }
}
