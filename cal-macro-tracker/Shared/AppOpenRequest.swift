import Foundation

enum AddFoodEntryPoint: String, Hashable, Identifiable {
    case addFood = "add-food"
    case scanBarcode = "scan-barcode"
    case scanLabel = "scan-label"
    case manualEntry = "manual-entry"

    var id: String { rawValue }
}

enum AppOpenRequest: Hashable {
    case dashboard
    case addFood(AddFoodEntryPoint)
    case sharing(inviteInput: String?)

    init?(url: URL) {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme == SharedAppConfiguration.deepLinkScheme
        else {
            return nil
        }

        switch components.host {
        case "dashboard":
            self = .dashboard
        case "add-food":
            let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let entryPoint = path.isEmpty ? .addFood : AddFoodEntryPoint(rawValue: path)
            guard let entryPoint else { return nil }
            self = .addFood(entryPoint)
        case "sharing":
            let pathComponents = components.path.split(separator: "/").map(String.init)
            if pathComponents.first == "invite", let token = pathComponents.dropFirst().first {
                self = .sharing(inviteInput: token)
            } else {
                self = .sharing(inviteInput: nil)
            }
        default:
            return nil
        }
    }

    var url: URL {
        switch self {
        case .dashboard:
            return URL(string: "\(SharedAppConfiguration.deepLinkScheme)://dashboard")!
        case let .addFood(entryPoint):
            if entryPoint == .addFood {
                return URL(string: "\(SharedAppConfiguration.deepLinkScheme)://add-food")!
            }

            return URL(string: "\(SharedAppConfiguration.deepLinkScheme)://add-food/\(entryPoint.rawValue)")!
        case let .sharing(inviteInput):
            if let inviteInput {
                return URL(string: "\(SharedAppConfiguration.deepLinkScheme)://sharing/invite/\(inviteInput)")!
            }
            return URL(string: "\(SharedAppConfiguration.deepLinkScheme)://sharing")!
        }
    }
}
