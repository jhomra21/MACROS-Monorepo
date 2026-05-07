import Foundation

enum SharingConfiguration {
    static let convexDeploymentURL = "https://energized-pigeon-822.convex.cloud"
    static let authBaseURL = URL(string: "https://macros-auth.jhonra121.workers.dev")!

    static func inviteAppURL(token: String) -> URL {
        AppOpenRequest.sharing(inviteInput: token).url
    }
}
