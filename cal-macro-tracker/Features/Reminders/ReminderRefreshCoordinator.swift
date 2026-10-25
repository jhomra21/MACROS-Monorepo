import Foundation

@MainActor
final class ReminderRefreshCoordinator {
    private var pendingOperation: (@MainActor () async -> Void)?
    private var refreshTask: Task<Void, Never>?

    func request(_ operation: @escaping @MainActor () async -> Void) {
        pendingOperation = operation
        guard refreshTask == nil else { return }
        refreshTask = Task { await drain() }
    }

    func waitUntilIdle() async {
        await refreshTask?.value
    }

    private func drain() async {
        while let operation = pendingOperation {
            pendingOperation = nil
            await operation()
        }
        refreshTask = nil
    }
}
