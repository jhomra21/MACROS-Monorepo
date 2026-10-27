import Charts
import SwiftData
import SwiftUI

struct InsightsWeightCard: View {
    @Query(sort: \WeightEntry.recordedAt) private var entries: [WeightEntry]
    @Query private var profiles: [BodyProfile]
    @Environment(AppEntitlements.self) private var entitlements

    let range: InsightsRange
    let today: CalendarDay
    @Binding var isPresentingPro: Bool

    private var allPoints: [WeightAnalyticsPoint] {
        entries.map { WeightAnalyticsPoint(day: $0.recordedAt, recordedAt: $0.recordedAt, weightKg: $0.weightKg) }
    }

    private var points: [WeightAnalyticsPoint] {
        guard let firstDay = range.days(endingOn: today).first else { return [] }
        let rangeStart = firstDay.startDate
        let rangeEnd = today.dayInterval.end
        return allPoints.filter { $0.recordedAt >= rangeStart && $0.recordedAt < rangeEnd }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let latest = WeightAnalytics.latest(from: allPoints) {
                let latestInRange = WeightAnalytics.latest(from: points)
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
                } else if let latestInRange {
                    if let comparison = WeightAnalytics.comparisonFromSevenDaysAgo(
                        in: allPoints,
                        endingOn: latestInRange.day
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
            } else {
                Text("No entries yet").foregroundStyle(.secondary)
            }
            NavigationLink(entries.isEmpty ? "Log your first weight" : "View weight log") { WeightScreen() }
        }
        .padding()
        .background(PlatformColors.cardBackground, in: RoundedRectangle(cornerRadius: 16))
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
