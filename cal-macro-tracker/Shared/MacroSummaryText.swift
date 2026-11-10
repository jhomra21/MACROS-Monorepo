enum MacroSummaryText {
    /// "P 12g · C 34g · F 5g". Call sites keep their existing separator and unit so visible text is unchanged.
    static func line(
        protein: Double,
        carbs: Double,
        fat: Double,
        separator: String = " · ",
        unit: String = "g"
    ) -> String {
        [("P", protein), ("C", carbs), ("F", fat)]
            .map { "\($0.0) \($0.1.roundedForDisplay)\(unit)" }
            .joined(separator: separator)
    }
}
