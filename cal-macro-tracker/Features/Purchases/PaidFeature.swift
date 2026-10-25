enum PaidEntitlement {
    case pro
}

enum PaidFeature: CaseIterable {
    case customMacroRingColors
    case nutritionInsights
    case weightTrends
    case healthSync
    case backup
    case multipleReminders

    var requiredEntitlement: PaidEntitlement {
        .pro
    }
}
