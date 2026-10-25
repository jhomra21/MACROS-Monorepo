import Charts
import SwiftData
import SwiftUI

struct InsightsWeightCard: View {
    @Query(sort: \WeightEntry.recordedAt) private var entries: [WeightEntry]
    @Query private var profiles: [BodyProfile]
    @Environment(AppEntitlements.self) private var entitlements
    @State private var isPresentingPro = false

    let range: InsightsRange
    let today: CalendarDay

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
                    Text(
                        Measurement(
                            value: displayWeight(latest.weightKg),
                            unit: isMetric ? UnitMass.kilograms : UnitMass.pounds
                        )
                        .formatted(.measurement(width: .narrow, usage: .asProvided))
                    )
                    .font(.title3.bold().monospacedDigit())
                }
                if entitlements.canUse(.weightTrends), let rate = WeightAnalytics.weeklyRate(from: points) {
                    Text("\(rate >= 0 ? "+" : "")\(displayWeight(rate), specifier: "%.2f") \(unitLabel)/week")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let latestInRange, let change = weeklyChange(endingAt: latestInRange) {
                    Text("\(change >= 0 ? "+" : "")\(displayWeight(change), specifier: "%.1f") \(unitLabel) in 7 days")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if points.count > 1 {
                    ZStack {
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
                        .blur(radius: entitlements.canUse(.weightTrends) ? 0 : 6)
                        .allowsHitTesting(entitlements.canUse(.weightTrends))
                        .accessibilityLabel("Weight trend chart")
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
        .sheet(isPresented: $isPresentingPro) {
            ProPaywallSheet(context: .weightTrends)
                .presentationDetents([.medium, .large])
        }
    }

    private var isMetric: Bool {
        BodyProfile.activeRecord(from: profiles)?.unitSystem != .imperial
    }

    private var unitLabel: String { isMetric ? "kg" : "lb" }

    private func displayWeight(_ kilograms: Double) -> Double {
        isMetric ? kilograms : GoalCalculator.pounds(fromKg: kilograms)
    }

    private func weeklyChange(endingAt latest: WeightAnalyticsPoint) -> Double? {
        guard let targetDate = Calendar.current.date(byAdding: .day, value: -7, to: latest.day),
            let prior = allPoints.filter({ $0.day <= targetDate }).max(by: { $0.day < $1.day })
        else { return nil }
        return latest.weightKg - prior.weightKg
    }
}
