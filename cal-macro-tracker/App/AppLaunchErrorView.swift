import SwiftUI

struct AppLaunchErrorView: View {
    let message: String

    var body: some View {
        ContentUnavailableView(
            "Unable to Start App",
            systemImage: "exclamationmark.triangle",
            description: Text("\(message) Close the app completely and open it again.")
        )
        .padding(24)
    }
}
