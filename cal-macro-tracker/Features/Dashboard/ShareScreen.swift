#if os(iOS)
import SwiftUI
import UIKit

/// The "Post an image" sheet. Live sharing is a separate choice in the Home Share menu.
struct ShareScreen: View {
    private static let defaultCaption = "My macros today, tracked with MACROS. macrosios.com"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let day: CalendarDay
    let snapshot: LogEntryDaySnapshot
    let goals: MacroGoalsSnapshot

    @State private var size = ShareImageSize.story
    @State private var detail = ShareDetail.macros
    @State private var caption = Self.defaultCaption
    @State private var captionWasCopied = false
    @State private var isRendering = false
    @State private var showsRenderFailure = false
    @State private var activityPayload: ShareActivityPayload?

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                optionsSection
                captionSection
            }
            .navigationTitle("Share")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { shareButton }
            .onChange(of: caption) { captionWasCopied = false }
            .sheet(item: $activityPayload) { payload in
                ActivityShareSheet(activityItems: payload.items)
            }
            .alert("Something went wrong sharing.", isPresented: $showsRenderFailure) {
                Button("Retry", action: share)
                Button("Cancel", role: .cancel) {}
            }
        }
        .presentationDetents([.large])
    }

    private var previewSection: some View {
        Section {
            GeometryReader { proxy in
                DailyShareCardView(day: day, snapshot: snapshot, goals: goals, size: size, detail: detail)
                    .scaleEffect(proxy.size.width / size.canvas.width, anchor: .topLeading)
            }
            .aspectRatio(size.canvas.width / size.canvas.height, contentMode: .fit)
            .frame(maxHeight: 300)
            .clipShape(.rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.separator) }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("share-preview")
            .accessibilityLabel(previewLabel)
            .accessibilityValue("\(size.title), \(detail.title)")
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    private var previewLabel: String {
        let totals = snapshot.totals
        return "Image preview, \(totals.calories.roundedForDisplay) calories, "
            + MacroSummaryText.line(protein: totals.protein, carbs: totals.carbs, fat: totals.fat)
    }

    private var optionsSection: some View {
        Section {
            Picker("Size", selection: $size) {
                ForEach(ShareImageSize.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("share-size-picker")

            Picker("Detail", selection: $detail) {
                ForEach(ShareDetail.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("share-detail-picker")
        }
    }

    private var captionSection: some View {
        Section {
            TextField("Caption", text: $caption, axis: .vertical)
                .lineLimit(1...4)
                .accessibilityIdentifier("share-caption")

            Button("Copy caption", systemImage: "doc.on.doc", action: copyCaption)
                .disabled(caption.isEmpty)
        } header: {
            Text("Caption")
        } footer: {
            if captionWasCopied {
                Text("Caption copied. Paste it in your post.")
            }
        }
    }

    private var shareButton: some View {
        Button(action: share) {
            Label(isRendering ? "Preparing…" : "Share", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .disabled(isRendering)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .accessibilityIdentifier("share-submit")
    }

    private func copyCaption() {
        guard !caption.isEmpty else { return }
        UIPasteboard.general.string = caption
        #if DEBUG
        UITestFixture.current?.recordPasteboard()
        #endif
        captionWasCopied = true
        AccessibilityNotification.Announcement("Caption copied. Paste it in your post.").post()
    }

    private func share() {
        guard !isRendering else { return }
        isRendering = true
        Task { @MainActor in
            defer { isRendering = false }
            do {
                let image = try DailyShareImageExporter.exportImage(
                    day: day, snapshot: snapshot, goals: goals, size: size, detail: detail, colorScheme: colorScheme
                )
                #if DEBUG
                UITestFixture.current?.recordExport(image, name: "\(size.title)-\(detail.title)")
                #endif
                copyCaption()
                activityPayload = ShareActivityPayload(day: day, image: image, caption: caption)
            } catch {
                showsRenderFailure = true
            }
        }
    }
}

private struct ShareActivityPayload: Identifiable {
    let id = UUID()
    let items: [Any]

    init(day: CalendarDay, image: UIImage, caption: String) {
        let title = day.startDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())
        let imageItem = DashboardShareImageItemSource(image: image, title: title)
        items = caption.isEmpty ? [imageItem] : [imageItem, DashboardShareCaptionItemSource(caption: caption)]
    }
}
#endif
