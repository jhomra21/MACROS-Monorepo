import SwiftUI

struct FoodDraftSourceSection: View {
    struct Action {
        let message: String
        let title: String
        let isDisabled: Bool
        let action: () -> Void
    }

    let title: String
    let notes: [String]
    let sourceNameLabel: String
    let sourceName: String?
    let sourceURL: URL?
    let previewActionTitle: String?
    let onPreview: (() -> Void)?
    let sourceAction: Action?

    init(
        title: String,
        notes: [String] = [],
        sourceNameLabel: String = "Source",
        sourceName: String? = nil,
        sourceURL: URL? = nil,
        previewActionTitle: String? = nil,
        onPreview: (() -> Void)? = nil,
        sourceAction: Action? = nil
    ) {
        self.title = title
        self.notes = notes
        self.sourceNameLabel = sourceNameLabel
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.previewActionTitle = previewActionTitle
        self.onPreview = onPreview
        self.sourceAction = sourceAction
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

                if let sourceAction {
                    Text(sourceAction.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button(sourceAction.title, action: sourceAction.action)
                        .disabled(sourceAction.isDisabled)
                }
            }
        }
    }

    private var hasVisibleContent: Bool {
        notes.isEmpty == false
            || sourceName != nil
            || sourceURL != nil
            || (previewActionTitle != nil && onPreview != nil)
            || sourceAction != nil
    }
}
