import SwiftUI

extension DashboardScreen {
    func dashboardToolbarTrailing(snapshot: LogEntryDaySnapshot) -> some ToolbarContent {
        ToolbarItem(placement: .appTopBarTrailing) {
            HStack(spacing: 8) {
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

                Button(action: onOpenInsights) {
                    Image(systemName: "chart.xyaxis.line")
                        .appTopBarIconStyle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open insights")

                Button(action: onOpenHistory) {
                    Image(systemName: "calendar")
                        .appTopBarIconStyle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open history")

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .appTopBarIconStyle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open settings")
            }
            .padding(.horizontal, 4)
            .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private var shareButtonLabel: some View {
        #if os(iOS)
        if isPreparingShare {
            ProgressView()
                .controlSize(.small)
                .frame(width: 32, height: 32)
        } else {
            Image(systemName: "square.and.arrow.up")
                .appTopBarIconStyle()
                .frame(width: 32, height: 32)
                .offset(y: -2)
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
