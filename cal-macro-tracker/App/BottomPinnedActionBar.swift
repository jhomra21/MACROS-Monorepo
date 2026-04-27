import SwiftUI

struct BottomPinnedActionBar: View {
    let title: String
    let systemImage: String?
    let isDisabled: Bool
    var topPadding: CGFloat = 10
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, macOS 26, *) {
            Button(action: action) {
                labelContent
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 20)
            .padding(.top, topPadding)
            .padding(.bottom, 8)
            .disabled(isDisabled)
        } else {
            Button(action: action) {
                labelContent
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(isDisabled ? Color.secondary.opacity(0.5) : Color.black)
                    .clipShape(Capsule())
                    .padding(.horizontal, 20)
                    .padding(.top, topPadding)
                    .padding(.bottom, 8)
                    .background(.ultraThinMaterial)
            }
            .disabled(isDisabled)
        }
    }

    private var labelContent: some View {
        HStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.headline)
            }

            Text(title)
                .font(.headline.weight(.semibold))
        }
    }
}
