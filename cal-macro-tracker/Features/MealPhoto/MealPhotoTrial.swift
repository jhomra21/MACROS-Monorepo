/// Free scans for people without Pro. The count lives on the device and never leaves it.
nonisolated enum MealPhotoTrial {
    static let freeScans = 5

    static func remaining(used: Int) -> Int {
        max(0, freeScans - used)
    }

    static func canScan(hasPro: Bool, used: Int) -> Bool {
        hasPro || remaining(used: used) > 0
    }

    /// Pro scans are unlimited and do not use up the trial.
    static func used(afterSuccessfulScan used: Int, hasPro: Bool) -> Int {
        hasPro ? used : min(used + 1, freeScans)
    }
}
