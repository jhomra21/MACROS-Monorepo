#if os(iOS)
import PhotosUI
import SwiftUI
import UIKit

struct WidgetBackgroundSettingsSection: View {
    @Environment(AppEntitlements.self) private var entitlements
    @Binding var paywallContext: ProPaywallContext?
    @State private var photoItem: PhotosPickerItem?
    @State private var selection = WidgetAppearanceStorage.shared.background
    @State private var errorMessage: String?
    @State private var isImporting = false
    @State private var requestIdentifier: UUID?
    @State private var importTask: Task<Void, Never>?

    var body: some View {
        Section {
            PaidFeatureGate(.customWidgetBackground) {
                Button {
                    select(.native)
                } label: {
                    selectionRow(
                        "Native",
                        subtitle: "Let iOS choose the widget appearance.",
                        symbol: "circle.lefthalf.filled",
                        selected: selection == .native
                    )
                }
                .buttonStyle(.plain)

                Button {
                    presentColorPicker()
                } label: {
                    selectionRow(
                        "Color",
                        subtitle: selectionColorDescription,
                        spokenSubtitle: isColorSelected ? "Custom color" : nil,
                        symbol: "paintpalette",
                        selected: isColorSelected
                    )
                }
                .buttonStyle(.plain)

                PhotosPicker(selection: $photoItem, matching: .images) {
                    selectionRow(
                        "Photo",
                        subtitle: isPhotoSelected ? "Device-local photo" : "Choose a photo from your library.",
                        symbol: "photo",
                        selected: isPhotoSelected
                    )
                }
                .disabled(!entitlements.canUse(.customWidgetBackground))

                if isImporting {
                    ProgressView("Preparing widget photo…")
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Widget background status. \(errorMessage)")
                }
            } locked: {
                Button {
                    paywallContext = .widgetBackground
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Customize Widget Background")
                                .foregroundStyle(Color.accentColor)
                            Text("Included with \(AppBrand.displayName) Pro")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button("Restore Default") {
                select(.native)
            }
        } header: {
            Text("Widget Background")
        } footer: {
            Text("Photos stay on this device. Clear and tinted Home Screen appearances are controlled by iOS.")
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            importPhoto(item)
        }
        .onChange(of: entitlements.hasPro) { _, hasPro in
            guard !hasPro else { return }
            requestIdentifier = nil
            importTask?.cancel()
            importTask = nil
            isImporting = false
            photoItem = nil
        }
        .onAppear {
            selection = WidgetAppearanceStorage.shared.background
        }
        .onDisappear {
            requestIdentifier = nil
            importTask?.cancel()
            importTask = nil
            isImporting = false
            photoItem = nil
        }
    }

    private var isColorSelected: Bool {
        if case .color = selection { true } else { false }
    }

    private var isPhotoSelected: Bool {
        if case .photo = selection { true } else { false }
    }

    private var selectionColorDescription: String {
        guard case let .color(hex) = selection else { return "Choose a solid color." }
        return hex
    }

    private func selectionRow(
        _ title: String,
        subtitle: String,
        spokenSubtitle: String? = nil,
        symbol: String,
        selected: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .accessibilityLabel(spokenSubtitle ?? subtitle)
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func select(_ newSelection: WidgetBackgroundSelection) {
        importTask?.cancel()
        importTask = nil
        requestIdentifier = nil
        isImporting = false
        photoItem = nil
        do {
            try WidgetBackgroundPhotoImport.writeSelection(newSelection)
            selection = newSelection
            errorMessage = nil
            WidgetTimelineReloader.reloadMacroWidgets()
        } catch {
            selection = WidgetAppearanceStorage.shared.background
            errorMessage = error.localizedDescription
            if selection == newSelection {
                WidgetTimelineReloader.reloadMacroWidgets()
            }
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        importTask?.cancel()
        let request = UUID()
        requestIdentifier = request
        isImporting = true
        errorMessage = nil
        importTask = Task {
            defer {
                if requestIdentifier == request {
                    isImporting = false
                    photoItem = nil
                    importTask = nil
                }
            }
            do {
                let jpeg = try await WidgetBackgroundPhotoImport.jpegData(from: item)
                try Task.checkCancellation()
                guard requestIdentifier == request,
                    entitlements.canUse(.customWidgetBackground)
                else { return }
                let identifier = try WidgetBackgroundPhotoImport.commit(jpeg)
                guard requestIdentifier == request else { return }
                selection = .photo(identifier: identifier)
                errorMessage = nil
                WidgetTimelineReloader.reloadMacroWidgets()
            } catch {
                guard requestIdentifier == request, !Task.isCancelled else { return }
                selection = WidgetAppearanceStorage.shared.background
                errorMessage = error.localizedDescription
                if isPhotoSelected {
                    WidgetTimelineReloader.reloadMacroWidgets()
                }
            }
        }
    }

    private func presentColorPicker() {
        let initialColor: Color
        if case let .color(hex) = selection {
            initialColor = Color(hex: hex) ?? .accentColor
        } else {
            initialColor = .accentColor
        }
        var didChangeColor = false
        ColorPickerPresenter.present(initialColor: initialColor) { color in
            guard entitlements.canUse(.customWidgetBackground),
                let hex = Color(color).hexString,
                let validatedColor = WidgetBackgroundSelection.validatedColor(hex)
            else { return }
            importTask?.cancel()
            importTask = nil
            requestIdentifier = nil
            isImporting = false
            photoItem = nil
            do {
                try WidgetBackgroundPhotoImport.writeSelection(validatedColor)
                selection = validatedColor
                errorMessage = nil
                didChangeColor = true
            } catch {
                selection = WidgetAppearanceStorage.shared.background
                errorMessage = error.localizedDescription
                didChangeColor = selection == validatedColor
            }
        } onFinish: {
            if didChangeColor {
                WidgetTimelineReloader.reloadMacroWidgets()
            }
        }
    }
}
#endif
