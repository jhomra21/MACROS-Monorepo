import SwiftData
import SwiftUI

struct LogEntryDaySnapshotReader<Content: View>: View {
    @Query private var entries: [LogEntry]

    private let content: (LogEntryDaySnapshot) -> Content

    init(date: Date, @ViewBuilder content: @escaping (LogEntryDaySnapshot) -> Content) {
        _entries = Query(LogEntryDaySummary.descriptor(for: date))
        self.content = content
    }

    var body: some View {
        content(LogEntryDaySummary.snapshot(for: entries))
    }
}
