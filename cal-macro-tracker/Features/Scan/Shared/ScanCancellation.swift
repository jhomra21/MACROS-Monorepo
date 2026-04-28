import Foundation

enum ScanCancellation {
    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        return (error as? URLError)?.code == .cancelled
    }
}
