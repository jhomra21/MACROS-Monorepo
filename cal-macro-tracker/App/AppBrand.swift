import Foundation

enum AppBrand {
    static let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "MACROS"
}
