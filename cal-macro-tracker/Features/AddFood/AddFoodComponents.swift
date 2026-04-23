import SwiftUI

struct AddFoodQuickActions: View {
    let onFoodLogged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan")
                .font(.headline)

            if #available(iOS 26, macOS 26, *) {
                GlassEffectContainer(spacing: 10) {
                    quickActionLinks
                }
            } else {
                quickActionLinks
            }
        }
    }

    private var quickActionLinks: some View {
        HStack(alignment: .top, spacing: 10) {
            NavigationLink {
                BarcodeScanScreen(onFoodLogged: onFoodLogged, entryMode: .immediateCamera)
            } label: {
                quickActionCard(title: "Scan Barcode", systemImage: "barcode.viewfinder")
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)

            NavigationLink {
                LabelScanScreen(onFoodLogged: onFoodLogged)
            } label: {
                quickActionCard(title: "Scan Label", systemImage: "camera.viewfinder")
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)
        }
    }

    private func quickActionCard(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.primary)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading)
        .appGlassRoundedRect(cornerRadius: 18)
    }
}

enum AddFoodMode: String, CaseIterable, Identifiable {
    case search
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search: "Search"
        case .manual: "Manual"
        }
    }
}

struct ManualFoodEntryScreen: View {
    let onFoodLogged: () -> Void

    @State private var draft = FoodDraft()
    @State private var numericText = FoodDraftNumericText(draft: FoodDraft())
    @State private var errorMessage: String?
    @FocusState private var focusedField: FoodDraftField?

    var body: some View {
        FoodDraftEditorForm(
            draft: $draft,
            numericText: $numericText,
            errorMessage: $errorMessage,
            brandPrompt: "Brand (optional)",
            gramsPrompt: "Grams per serving (optional)",
            focusedField: $focusedField,
            trailingKeyboardFields: []
        ) {
            EmptyView()
        } footerSections: {
            Section {
                NavigationLink {
                    LogFoodScreen(
                        initialDraft: numericText.finalizedDraft(from: draft) ?? draft,
                        onFoodLogged: onFoodLogged
                    )
                } label: {
                    Text("Continue")
                }
                .disabled(!canContinue)
            }
        }
    }

    private var canContinue: Bool {
        guard let finalizedDraft = numericText.finalizedDraft(from: draft) else { return false }
        return finalizedDraft.canSaveReusableFood
    }
}
