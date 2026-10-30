enum PaidEntitlement {
    case pro
}

enum PaidFeature: CaseIterable {
    case customMacroRingColors
    case nutritionInsights
    case weightTrends
    case healthWeightImport
    case backup
    case multipleReminders
    case customWidgetBackground
    case sharingInvites

    var requiredEntitlement: PaidEntitlement {
        .pro
    }
}
