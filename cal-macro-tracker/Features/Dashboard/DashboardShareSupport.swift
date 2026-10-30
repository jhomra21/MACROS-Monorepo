import SwiftUI

extension DashboardScreen {
    @ToolbarContentBuilder
    func dashboardToolbarTrailing(snapshot: LogEntryDaySnapshot) -> some ToolbarContent {
        ToolbarItemGroup(placement: .appTopBarTrailing) {
            #if os(iOS)
            Button {
                prepareShare(for: snapshot)
            } label: {
                shareButtonLabel
            }
            .labelStyle(.iconOnly)
            .disabled(isPreparingShare)
            .accessibilityLabel("Share daily summary")
            #endif

            Button("Open Insights", systemImage: "chart.xyaxis.line", action: onOpenInsights)
                .labelStyle(.iconOnly)

            Button("Open History", systemImage: "calendar", action: onOpenHistory)
                .labelStyle(.iconOnly)

            Button("Open Settings", systemImage: "gearshape", action: onOpenSettings)
                .labelStyle(.iconOnly)
        }
    }

    @ViewBuilder
    private var shareButtonLabel: some View {
        #if os(iOS)
        if isPreparingShare {
            ProgressView()
        } else {
            Label("Share daily summary", systemImage: "square.and.arrow.up")
        }
        #endif
    }
}

#if os(iOS)
extension DashboardScreen {
    private static var maximumSharePreparationAttempts: Int { 3 }

    func prepareShare(for snapshot: LogEntryDaySnapshot) {
        guard !isPreparingShare else { return }

        prepareShare(day: daySelection.selectedDay, snapshot: snapshot)
    }

    func prepareShare(day: CalendarDay, snapshot: LogEntryDaySnapshot) {
        isPreparingShare = true
        Task { @MainActor in
            do {
                let image = try prepareShareImage(day: day, snapshot: snapshot)
                shareSheetItem = DashboardShareSheetItem(day: day, image: image)
            } catch {
                shareFailureRequest = ShareFailureRequest(day: day, snapshot: snapshot)
            }
            isPreparingShare = false
        }
    }

    private func prepareShareImage(day: CalendarDay, snapshot: LogEntryDaySnapshot) throws -> UIImage {
        var lastError: Error = DailyShareImageExportError.renderingFailed

        for _ in 0..<Self.maximumSharePreparationAttempts {
            do {
                return try DailyShareImageExporter.exportImage(
                    day: day,
                    snapshot: snapshot,
                    goals: currentGoals,
                    colorScheme: colorScheme
                )
            } catch {
                lastError = error
            }
        }

        throw lastError
    }
}

struct DashboardShareSheetItem: Identifiable {
    let id = UUID()
    let itemSource: DashboardShareImageItemSource

    init(day: CalendarDay, image: UIImage) {
        itemSource = DashboardShareImageItemSource(image: image, title: day.shareTitle)
    }
}

private extension CalendarDay {
    var shareTitle: String {
        startDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())
    }
}

struct ShareFailureRequest: Identifiable {
    let id = UUID()
    let day: CalendarDay
    let snapshot: LogEntryDaySnapshot
}
#endif
