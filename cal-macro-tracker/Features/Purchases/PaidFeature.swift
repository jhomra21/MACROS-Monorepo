enum PaidEntitlement {
    case fullUnlock
}

enum PaidFeature {
    case customMacroRingColors
    case nutritionInsights

    var requiredEntitlement: PaidEntitlement {
        switch self {
        case .customMacroRingColors, .nutritionInsights:
            .fullUnlock
        }
    }
}
