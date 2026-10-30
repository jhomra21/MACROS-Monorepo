import SwiftUI

extension DashboardScreen {
    func dashboardToolbarTrailing(snapshot: LogEntryDaySnapshot) -> some ToolbarContent {
        ToolbarItem(placement: .appTopBarTrailing) {
            HStack(spacing: 0) {
                #if os(iOS)
                Button {
                    prepareShare(for: snapshot)
                } label: {
                    shareButtonLabel
                }
                .buttonStyle(.plain)
                .disabled(isPreparingShare)
                .accessibilityLabel("Share daily summary")
                #endif
                toolbarIcon("chart.xyaxis.line", label: "Open insights", action: onOpenInsights)
                toolbarIcon("calendar", label: "Open history", action: onOpenHistory)
                toolbarIcon("gearshape", label: "Open settings", action: onOpenSettings)
            }
            .foregroundStyle(.primary)
        }
    }

    private func toolbarIcon(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .appTopBarIconStyle()
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var shareButtonLabel: some View {
        #if os(iOS)
        if isPreparingShare {
            ProgressView()
                .controlSize(.small)
                .frame(width: 44, height: 44)
        } else {
            Image(systemName: "square.and.arrow.up")
                .appTopBarIconStyle()
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
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
