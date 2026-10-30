import Charts
import SwiftData
import SwiftUI

struct InsightsWeightCard: View {
    @Query private var entries: [WeightEntry]
    @Query private var profiles: [BodyProfile]
    @Environment(AppEntitlements.self) private var entitlements

    let range: InsightsRange
    let today: CalendarDay
    @Binding var isPresentingPro: Bool

    init(range: InsightsRange, today: CalendarDay, isPresentingPro: Binding<Bool>) {
        self.range = range
        self.today = today
        self._isPresentingPro = isPresentingPro
        let rangeStart =
            range == .allTime
            ? Date.distantPast
            : (range.days(endingOn: today).first?.startDate ?? today.startDate)
        let start: Date
        if range == .allTime {
            start = rangeStart
        } else {
            start = today.resolvedCalendar.date(byAdding: .day, value: -7, to: rangeStart) ?? rangeStart
        }
        let end = today.dayInterval.end
        let predicate = #Predicate<WeightEntry> { entry in
            entry.recordedAt >= start && entry.recordedAt < end
        }
        _entries = Query(
            FetchDescriptor(
                predicate: predicate,
                sortBy: [SortDescriptor(\WeightEntry.recordedAt)]
            )
        )
    }

    private var allPoints: [WeightAnalyticsPoint] {
        entries.map { WeightAnalyticsPoint(day: $0.recordedAt, recordedAt: $0.recordedAt, weightKg: $0.weightKg) }
    }

    private var points: [WeightAnalyticsPoint] {
        guard range != .allTime,
            let rangeStart = range.days(endingOn: today).first?.startDate
        else {
            return allPoints
        }
        return allPoints.filter { $0.recordedAt >= rangeStart && $0.recordedAt < today.dayInterval.end }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let latest = WeightAnalytics.latest(from: points) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Weight").font(.headline)
                        Spacer()
                        Text("\(displayWeight(latest.weightKg), specifier: "%.1f") \(unitLabel)")
                            .font(.title3.bold().monospacedDigit())
                    }
                    if entitlements.canUse(.weightTrends), let rate = WeightAnalytics.weeklyRate(from: points) {
                        Text("\(rate >= 0 ? "+" : "")\(displayWeight(rate), specifier: "%.2f") \(unitLabel)/week")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        if let comparison = WeightAnalytics.comparisonFromSevenDaysAgo(
                            in: allPoints,
                            endingOn: latest.day
                        ) {
                            let label = "since \(comparison.baselineDay.formatted(date: .abbreviated, time: .omitted))"
                            Text(
                                "\(comparison.changeKg >= 0 ? "+" : "")\(displayWeight(comparison.changeKg), specifier: "%.1f") \(unitLabel) \(label)"
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        } else {
                            Text("No weight 7 days ago")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if points.count > 1 {
                        ZStack {
                            PaidFeatureGate(.weightTrends) {
                                trendChart
                            } locked: {
                                trendChart
                                    .blur(radius: 6)
                                    .accessibilityHidden(true)
                            }
                            if !entitlements.canUse(.weightTrends) {
                                Button {
                                    isPresentingPro = true
                                } label: {
                                    Label("Unlock weight trends with Pro", systemImage: "lock.fill")
                                        .frame(maxWidth: .infinity, minHeight: 48)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    NavigationLink("View weight log") {
                        WeightScreen()
                    }
                }
                .padding()
                .background(PlatformColors.cardBackground, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var isMetric: Bool {
        BodyProfile.activeRecord(from: profiles)?.unitSystem != .imperial
    }

    private var unitLabel: String { isMetric ? "kg" : "lb" }

    private func displayWeight(_ kilograms: Double) -> Double {
        isMetric ? kilograms : GoalCalculator.pounds(fromKg: kilograms)
    }

    private var trendChart: some View {
        Chart {
            ForEach(points, id: \.recordedAt) { point in
                PointMark(
                    x: .value("Date", point.day),
                    y: .value("Weight", displayWeight(point.weightKg))
                )
                .foregroundStyle(.secondary)
            }
            ForEach(WeightAnalytics.movingAverages(from: points)) { point in
                LineMark(
                    x: .value("Date", point.day),
                    y: .value("7-day average", displayWeight(point.averageKg))
                )
                .foregroundStyle(Color.accentColor)
                .interpolationMethod(.catmullRom)
            }
        }
        .frame(height: 150)
        .accessibilityLabel("Weight trend chart")
    }
}
