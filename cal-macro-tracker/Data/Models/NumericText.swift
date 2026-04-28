import Foundation

enum NumericText {
    enum State: Equatable {
        case empty
        case valid(Double)
        case invalid

        var isInvalid: Bool {
            if case .invalid = self {
                return true
            }

            return false
        }
    }

    static func editingDisplay(for value: Double, emptyWhenZero: Bool = false) -> String {
        if emptyWhenZero, abs(value) < 0.000_1 {
            return ""
        }

        return value.formatted(numberStyle)
    }

    static func editingDisplay(for value: Double?) -> String {
        guard let value else { return "" }
        return editingDisplay(for: value)
    }

    static func state(for text: String) -> State {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        do {
            let value = try numberStyle.parseStrategy.parse(trimmed)
            return value.isFinite ? .valid(value) : .invalid
        } catch {
            if let number = Double(trimmed) {
                return number.isFinite ? .valid(number) : .invalid
            }

            return .invalid
        }
    }

    private static let numberStyle = FloatingPointFormatStyle<Double>.number
        .grouping(.never)
        .precision(.fractionLength(0...16))
        .locale(.current)
}

extension Double {
    var hasVisiblePositiveDisplayValue: Bool {
        guard self > 0 else { return false }

        let displayedValue = roundedForDisplay
        return displayedValue != "0" && displayedValue != "0.0"
    }

    var roundedForDisplay: String {
        if abs(self.rounded() - self) < 0.01 {
            return String(Int(self.rounded()))
        }

        return String(format: "%.1f", self)
    }
}
