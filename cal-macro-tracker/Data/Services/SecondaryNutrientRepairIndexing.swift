import Foundation

extension SecondaryNutrientRepairService {
    static func unambiguousValuesByKey<Value>(
        _ values: [Value],
        key: (Value) -> SecondaryNutrientRepairKey
    ) -> [SecondaryNutrientRepairKey: Value] {
        var matches: [SecondaryNutrientRepairKey: Value] = [:]
        var ambiguousKeys = Set<SecondaryNutrientRepairKey>()

        for value in values {
            let key = key(value)
            if matches[key] != nil {
                ambiguousKeys.insert(key)
            } else {
                matches[key] = value
            }
        }

        ambiguousKeys.forEach { matches.removeValue(forKey: $0) }
        return matches
    }
}
