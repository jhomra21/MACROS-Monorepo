import SwiftData
import SwiftUI

/// Presents the milestone sheet once per newly earned badge, after a food is logged and Today has gone quiet.
struct StreakCelebrationModifier: ViewModifier {
    let isTodayIdle: Bool
    @Binding var celebration: StreakBadge?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppDayContext.self) private var dayContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppStorageKeys.streakFlexDays) private var flexDays = ""
    @AppStorage(AppStorageKeys.streakHighestBadgeDays) private var highestBadgeDays = 0
    @AppStorage(AppStorageKeys.streakCelebratedBadgeDays) private var celebratedBadgeDays = 0
    @AppStorage(AppStorageKeys.isProPaywallPresented) private var isPaywallPresented = false
    @State private var isPending = false

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .didSuccessfullyLogFood)) { _ in
                isPending = true
            }
            .task(id: canPresent) {
                guard canPresent else { return }
                // A short pause after the add sheet closes, so the sheet does not land on top of the dismissal.
                // The task restarts whenever the conditions change, so leaving Today cancels it.
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                guard canPresent else { return }
                isPending = false
                presentNewlyEarnedBadge()
            }
            .sheet(item: $celebration) { badge in
                StreakMilestoneSheet(badge: badge)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
    }

    private var canPresent: Bool {
        isPending && isTodayIdle && !isPaywallPresented && scenePhase == .active && celebration == nil
    }

    private func presentNewlyEarnedBadge() {
        var descriptor = LogEntryQuery.descriptor(start: .distantPast, end: dayContext.today.dayInterval.end, order: .forward)
        descriptor.propertiesToFetch = [\LogEntry.dateLogged, \LogEntry.createdAt]
        guard let entries = try? modelContext.fetch(descriptor) else { return }

        let today = dayContext.today
        let summary = LoggingStreakSummary.make(
            entries: entries.map { LoggingStreakEntry(dateLogged: $0.dateLogged, createdAt: $0.createdAt) },
            today: today,
            flexDays: FlexDayMarks.days(from: flexDays, calendar: today.resolvedCalendar)
        )
        guard let highest = StreakBadge.earned(best: summary.best, highestEarnedDays: highestBadgeDays).last else { return }
        highestBadgeDays = max(highestBadgeDays, highest.days)
        guard highest.days > celebratedBadgeDays else { return }
        // Earning several at once (an existing long streak) shows only the highest and marks the lower ones seen.
        celebratedBadgeDays = highest.days
        celebration = highest
    }
}

struct StreakMilestoneSheet: View {
    let badge: StreakBadge

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 0.0
    @State private var didAppear = false
    @State private var shareImage: Image?

    var body: some View {
        StreakPaletteReader { palette in
            ScrollView {
                VStack(spacing: 20) {
                    StreakMedallionView(badge: badge, palette: palette, progress: progress, diameter: 160)
                    VStack(spacing: 6) {
                        Text(badge.title)
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text(badge.celebrationLine)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    actions
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .task {
                shareImage = StreakShareCard.render(badge: badge, palette: palette, colorScheme: colorScheme)
            }
        }
        .accessibilityIdentifier("streak-milestone-sheet")
        .sensoryFeedback(.success, trigger: didAppear)
        .onAppear {
            didAppear = true
            if reduceMotion {
                progress = 1
            } else {
                withAnimation(.easeOut(duration: 1.1)) { progress = 1 }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            if let shareImage {
                ShareLink(item: shareImage, preview: SharePreview(badge.title, image: shareImage)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }
}

private extension StreakBadge {
    var celebrationLine: String { "\(days) days logged in a row." }
}

/// The image the Share button sends: the medallion, its name and the app name on a plain background.
private struct StreakShareCard: View {
    let badge: StreakBadge
    let palette: MacroRingPalette

    var body: some View {
        VStack(spacing: 18) {
            StreakMedallionView(badge: badge, palette: palette, diameter: 220)
            VStack(spacing: 6) {
                Text(badge.title).font(.largeTitle.bold())
                Text(badge.celebrationLine).font(.title3).foregroundStyle(.secondary)
            }
            Text(AppBrand.displayName)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding(.vertical, 48)
        .frame(width: 360)
        .background(PlatformColors.groupedBackground)
    }

    /// `ImageRenderer` does not inherit the environment, so the color scheme is passed in.
    @MainActor static func render(badge: StreakBadge, palette: MacroRingPalette, colorScheme: ColorScheme) -> Image? {
        #if os(iOS)
        let renderer = ImageRenderer(
            content: StreakShareCard(badge: badge, palette: palette).environment(\.colorScheme, colorScheme)
        )
        renderer.scale = 3
        return renderer.uiImage.map(Image.init(uiImage:))
        #else
        return nil
        #endif
    }
}
