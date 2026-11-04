import SwiftUI

final class AddFoodSearchScrollTracking {
    var lastOffset: CGFloat = 0
    var deepestOffset: CGFloat = 0

    func reset() {
        lastOffset = 0
        deepestOffset = 0
    }
}
