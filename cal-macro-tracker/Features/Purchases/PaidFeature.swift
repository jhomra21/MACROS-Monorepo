enum PaidEntitlement {
    case fullUnlock
}

enum PaidFeature {
    case customMacroRingColors

    var requiredEntitlement: PaidEntitlement {
        switch self {
        case .customMacroRingColors:
            .fullUnlock
        }
    }
}
