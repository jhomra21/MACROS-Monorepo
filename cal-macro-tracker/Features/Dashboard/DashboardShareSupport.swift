import SwiftUI

extension DashboardScreen {
    func dashboardToolbarTrailing(snapshot: LogEntryDaySnapshot) -> some ToolbarContent {
        ToolbarItem(placement: .appTopBarTrailing) {
            HStack(spacing: 8) {
                if daySelection.selectedDay != dayContext.today {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            daySelection.resetToToday(dayContext.today)
                        }
                    } label: {
                        Text("Today")
                            .fixedSize()
                    }
                    .buttonStyle(.plain)
                }

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

                Button(action: onOpenHistory) {
                    Image(systemName: "calendar")
                        .font(.title3.weight(.semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open history")

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .font(.title3.weight(.semibold))
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
                .font(.title3.weight(.semibold))
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
                let url = try prepareShareURL(day: day, snapshot: snapshot)
                shareSheetItem = DashboardShareSheetItem(url: url)
            } catch {
                shareFailureRequest = ShareFailureRequest(day: day, snapshot: snapshot)
            }
            isPreparingShare = false
        }
    }

    private func prepareShareURL(day: CalendarDay, snapshot: LogEntryDaySnapshot) throws -> URL {
        var lastError: Error = DailyShareImageExportError.renderingFailed

        for _ in 0..<Self.maximumSharePreparationAttempts {
            do {
                return try DailyShareImageExporter.exportPNG(
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
    let url: URL
}

struct ShareFailureRequest: Identifiable {
    let id = UUID()
    let day: CalendarDay
    let snapshot: LogEntryDaySnapshot
}
#endif
