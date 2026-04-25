import SwiftUI

struct FoodDraftSourceSection: View {
    let title: String
    let notes: [String]
    let sourceNameLabel: String
    let sourceName: String?
    let sourceURL: URL?
    let previewActionTitle: String?
    let onPreview: (() -> Void)?
    let actionMessage: String?
    let actionTitle: String?
    let isActionDisabled: Bool
    let onAction: (() -> Void)?

    init(
        title: String,
        notes: [String] = [],
        sourceNameLabel: String = "Source",
        sourceName: String? = nil,
        sourceURL: URL? = nil,
        previewActionTitle: String? = nil,
        onPreview: (() -> Void)? = nil,
        actionMessage: String? = nil,
        actionTitle: String? = nil,
        isActionDisabled: Bool = false,
        onAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.notes = notes
        self.sourceNameLabel = sourceNameLabel
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.previewActionTitle = previewActionTitle
        self.onPreview = onPreview
        self.actionMessage = actionMessage
        self.actionTitle = actionTitle
        self.isActionDisabled = isActionDisabled
        self.onAction = onAction
    }

    var body: some View {
        if hasVisibleContent {
            Section(title) {
                ForEach(notes, id: \.self) { note in
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let sourceName {
                    LabeledContent(sourceNameLabel) {
                        Text(sourceName)
                            .foregroundStyle(.secondary)
                    }
                }

                if let sourceURL {
                    Link(destination: sourceURL) {
                        Label("View Source", systemImage: "link")
                    }
                }

                if let previewActionTitle, let onPreview {
                    Button(previewActionTitle, action: onPreview)
                }

                if let actionMessage {
                    Text(actionMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let actionTitle, let onAction {
                    Button(actionTitle, action: onAction)
                        .disabled(isActionDisabled)
                }
            }
        }
    }

    private var hasVisibleContent: Bool {
        notes.isEmpty == false
            || sourceName != nil
            || sourceURL != nil
            || previewActionTitle != nil
            || actionMessage != nil
            || actionTitle != nil
    }
}
