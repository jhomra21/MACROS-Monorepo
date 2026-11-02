import Foundation

enum SharingConfiguration {
    static func inviteAppURL(token: String) -> URL {
        AppOpenRequest.sharing(inviteInput: token).url
    }
}
