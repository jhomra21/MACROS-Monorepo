import Observation
import SwiftUI
import UIKit

struct MealPhotoMessage: Equatable {
    let title: String
    let detail: String
    let canRetry: Bool

    static func scanFailed(_ error: MealPhotoError) -> Self {
        Self(title: "Scan didn't work", detail: error.errorDescription ?? "", canRetry: error.canRetry)
    }

    static func unreadablePhoto() -> Self {
        Self(title: "Couldn't read this photo", detail: "Try another photo, or search for the foods instead.", canRetry: false)
    }

    static func forStatus(_ status: MealPhotoEstimate.Status) -> Self? {
        switch status {
        case .ok:
            nil
        case .notFood:
            Self(title: "No food found", detail: "Try a photo with the meal in view, or search for the foods instead.", canRetry: false)
        case .unclear:
            Self(
                title: "Couldn't tell what's here", detail: "Try a closer, brighter photo, or search for the foods instead.",
                canRetry: false)
        case .packaged:
            Self(
                title: "This looks like packaged food",
                detail: "Scan its barcode or nutrition label with Camera for exact values.", canRetry: false)
        }
    }
}

/// Owns one meal photo scan: network, matching and review edits stay separate steps so any of them can fail on its own.
@MainActor
@Observable
final class MealPhotoSession {
    enum Phase: Equatable {
        case estimating
        case message(MealPhotoMessage)
        case review
    }

    private(set) var phase: Phase = .estimating
    var items: [MealPhotoItem] = []
    var hiddenFatAnswer: MealPhotoHiddenFatAnswer?

    private var estimate: MealPhotoEstimate?
    private var didSendFeedback = false
    private let client: MealPhotoClient

    init(client: MealPhotoClient = MealPhotoClient()) {
        self.client = client
    }

    var canLog: Bool {
        phase == .review && !items.isEmpty && items.allSatisfy(\.isReadyToLog)
    }

    func scan(_ image: UIImage, matcher: MealPhotoMatcher, onScanned: () -> Void) async {
        phase = .estimating
        let prepared = SendableScanImage(value: image)
        guard
            let jpeg = await Task.detached(
                priority: .userInitiated,
                operation: {
                    MealPhotoImagePreparer.jpegData(from: prepared.value)
                }
            ).value
        else {
            phase = .message(.unreadablePhoto())
            return
        }
        do {
            let estimate = try await client.estimate(jpeg: jpeg)
            guard !Task.isCancelled else { return }
            let status = estimate.status == .ok && estimate.foods.isEmpty ? .unclear : estimate.status
            if let message = MealPhotoMessage.forStatus(status) {
                phase = .message(message)
                return
            }
            onScanned()
            present(estimate, matcher: matcher)
        } catch {
            guard !Task.isCancelled else { return }
            phase = .message(.scanFailed(error as? MealPhotoError ?? .unavailable))
        }
    }

    func addOilItem(matcher: MealPhotoMatcher) {
        hiddenFatAnswer = .yes
        items.append(.oil(matching: matcher.localMatch(for: "Olive oil")))
    }

    func replaceFood(of id: UUID, with food: FoodDraft) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].replaceFood(with: food)
    }

    func log(using repository: LogEntryRepository, at date: Date) throws {
        let final = items
        for item in final {
            guard let action = item.loggingAction else { continue }
            try repository.logFood(action: action, loggedAt: date, operation: "Log meal photo food")
            items.removeAll { $0.id == item.id }
        }
        sendFeedback(final: final)
    }

    /// Reports once if the user leaves the review screen without logging.
    func finish() {
        if phase == .review { sendFeedback(final: items) }
    }

    private func present(_ estimate: MealPhotoEstimate, matcher: MealPhotoMatcher) {
        self.estimate = estimate
        items = estimate.foods.map { suggestion in
            .suggested(suggestion, food: suggestion.match.flatMap(matcher.serverMatch) ?? matcher.localMatch(for: suggestion.name))
        }
        phase = .review
    }

    private func sendFeedback(final: [MealPhotoItem]) {
        guard let estimate, !didSendFeedback else { return }
        didSendFeedback = true
        let feedback = MealPhotoFeedback.make(
            requestID: estimate.requestID,
            model: estimate.model,
            suggested: estimate.foods,
            final: final,
            hiddenFatAnswer: hiddenFatAnswer ?? .skipped
        )
        let client = client
        Task { await client.send(feedback) }
    }
}
