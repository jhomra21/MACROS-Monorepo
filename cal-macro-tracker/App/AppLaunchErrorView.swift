import SwiftUI

struct AppLaunchErrorView: View {
    let message: String

    var body: some View {
        ContentUnavailableView(
            "Unable to Start App",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
        .padding(24)
    }
}
