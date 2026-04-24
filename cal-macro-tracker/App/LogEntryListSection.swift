import SwiftUI

struct LogEntryListSection: View {
    enum Layout {
        case stackedCards
        case list
    }

    let title: String
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let entries: [LogEntry]
    let emptyVerticalPadding: Double
    let layout: Layout
    let showsHeader: Bool
    let onHeaderSwipeTranslation: ((CGSize) -> Void)?
    let onDeleteEntry: ((LogEntry) -> Void)?
    let onEditEntry: ((LogEntry) -> Void)?
    let onLogAgain: ((LogEntry) -> Void)?

    init(
        title: String,
        emptyTitle: String,
        emptySystemImage: String,
        emptyDescription: String,
        entries: [LogEntry],
        emptyVerticalPadding: Double,
        layout: Layout = .stackedCards,
        showsHeader: Bool = true,
        onHeaderSwipeTranslation: ((CGSize) -> Void)? = nil,
        onDeleteEntry: ((LogEntry) -> Void)? = nil,
        onEditEntry: ((LogEntry) -> Void)? = nil,
        onLogAgain: ((LogEntry) -> Void)? = nil
    ) {
        self.title = title
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.emptyDescription = emptyDescription
        self.entries = entries
        self.emptyVerticalPadding = emptyVerticalPadding
        self.layout = layout
        self.showsHeader = showsHeader
        self.onHeaderSwipeTranslation = onHeaderSwipeTranslation
        self.onDeleteEntry = onDeleteEntry
        self.onEditEntry = onEditEntry
        self.onLogAgain = onLogAgain
    }

    @ViewBuilder
    var body: some View {
        switch layout {
        case .stackedCards:
            stackedBody
        case .list:
            listBody
        }
    }

    private var headerView: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
            Text("\(entries.count) items")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    onHeaderSwipeTranslation?(value.translation)
                }
        )
    }

    private var emptyState: some View {
        ContentUnavailableView(
            emptyTitle,
            systemImage: emptySystemImage,
            description: Text(emptyDescription)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, emptyVerticalPadding)
        .background(PlatformColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var stackedBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsHeader {
                headerView
            }

            if entries.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(entries) { entry in
                        entryRow(for: entry)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var listBody: some View {
        Section {
            if showsHeader {
                headerView
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if entries.isEmpty {
                emptyState
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    entryRow(for: entry)
                        .overlay(alignment: .bottom) {
                            if index < entries.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 0.5)
                                    .padding(.top, 8)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
    }

    @ViewBuilder
    private func entryRow(for entry: LogEntry) -> some View {
        switch layout {
        case .stackedCards:
            interactiveEntryRow(
                NavigationLink {
                    EditLogEntryScreen(entry: entry)
                } label: {
                    LogEntryRow(entry: entry)
                },
                entry: entry
            )
        case .list:
            interactiveEntryRow(
                Button {
                    onEditEntry?(entry)
                } label: {
                    LogEntryRow(entry: entry)
                },
                entry: entry
            )
        }
    }

    private func interactiveEntryRow<Content: View>(_ content: Content, entry: LogEntry) -> some View {
        content
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if let onDeleteEntry {
                    Button("Delete", role: .destructive) {
                        onDeleteEntry(entry)
                    }
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                if let onEditEntry {
                    Button("Edit") {
                        onEditEntry(entry)
                    }
                    .tint(.gray)
                }

                if let onLogAgain {
                    Button("Log Again") {
                        onLogAgain(entry)
                    }
                    .tint(.blue)
                }
            }
    }
}
