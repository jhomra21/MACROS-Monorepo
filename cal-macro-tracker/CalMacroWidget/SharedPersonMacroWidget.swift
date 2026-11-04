#if os(iOS)
import AppIntents
import SwiftUI
import WidgetKit

struct SharedPersonMacroWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: SharedAppConfiguration.sharedPersonMacroWidgetKind,
            intent: SharedPersonWidgetIntent.self,
            provider: SharedPersonWidgetProvider()
        ) { entry in
            SharedPersonWidgetContentView(entry: entry, accessory: false)
                .containerBackground(for: .widget) {
                    if let layoutEntry = entry.layoutEntry {
                        DailyMacroWidgetBackground(entry: layoutEntry)
                    }
                }
        }
        .configurationDisplayName("Shared Macros")
        .description("Follow a person's calories and macros for today. Requires MACROS Pro.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable(true)
    }
}

struct SharedPersonMacroAccessoryWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: SharedAppConfiguration.sharedPersonMacroAccessoryWidgetKind,
            intent: SharedPersonWidgetIntent.self,
            provider: SharedPersonWidgetProvider(includesAppearance: false)
        ) { entry in
            SharedPersonWidgetContentView(entry: entry, accessory: true)
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        }
        .configurationDisplayName("Shared Macros Lock Screen")
        .description("Check a person's shared macros from your Lock Screen. Requires MACROS Pro.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private struct SharedPersonWidgetContentView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SharedPersonWidgetEntry
    let accessory: Bool

    var body: some View {
        Group {
            if entry.snapshot != nil, let layoutEntry = entry.layoutEntry {
                if accessory {
                    DailyMacroAccessoryWidgetContentView(
                        entry: layoutEntry, personName: entry.person?.name,
                        freshness: entry.freshness, offline: entry.offline
                    )
                } else {
                    DailyMacroWidgetContentView(
                        entry: layoutEntry, personName: entry.person?.name, freshness: entry.freshness
                    )
                }
            } else {
                statusContent
            }
        }
        .privacySensitive()
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
        .widgetURL(entry.url)
    }

    @ViewBuilder private var statusContent: some View {
        switch family {
        case .accessoryInline:
            Text([entry.person?.name, entry.status.compactMessage].compactMap { $0 }.joined(separator: " · "))
        case .accessoryCircular:
            VStack(spacing: 2) {
                Image(systemName: entry.status == .proLocked ? "lock.fill" : "person.crop.circle")
                if let person = entry.person { Text(person.name).lineLimit(1) }
                Text(entry.status.compactMessage).lineLimit(2)
            }
            .font(.system(size: 11))
            .multilineTextAlignment(.center)
        default:
            VStack(alignment: accessory ? .leading : .center, spacing: accessory ? 3 : 6) {
                if let person = entry.person {
                    Text(person.name).font(.caption.weight(.semibold)).lineLimit(1)
                }
                Text(entry.status.message)
                    .font(accessory ? .caption : .subheadline.weight(.semibold))
                    .multilineTextAlignment(accessory ? .leading : .center)
                    .lineLimit(3)
                if !accessory {
                    Text(entry.status == .unavailable ? "Edit Widget to choose someone" : "Open Sharing in MACROS")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: accessory ? .leading : .center)
        }
    }
}

private extension SharedPersonWidgetEntry {
    var freshness: String? {
        guard let snapshot else { return nil }
        let date = Date(timeIntervalSince1970: snapshot.updatedAt / 1000)
        return "\(offline ? "Offline · " : "")Updated \(date.formatted(date: .omitted, time: .shortened))"
    }
}
#endif
