import Observation
import SwiftUI

enum TutorialTarget: Hashable {
    case ringPanel
    case legend
    case todayPill
    /// Layout regions the caption is placed between.
    case contentArea
    case bottomBar
}

extension View {
    /// Frames are not cleared on disappear: pushing Sharing fires `onDisappear`, and the unchanged geometry
    /// would never be reported again when the dashboard returns. Outside a run only the ring panel keeps
    /// reporting; the other targets report until the dashboard is ready, which is what starts the run.
    func tutorialTarget(_ target: TutorialTarget, in tutorial: DashboardTutorial) -> some View {
        onGeometryChange(for: CGRect.self) {
            $0.frame(in: .global)
        } action: {
            guard tutorial.isRunning || !tutorial.isDashboardReady || target == .ringPanel else { return }
            tutorial.report($0, for: target)
        }
    }
}

/// Progress of the first-run Dashboard tutorial. Each event is ignored unless it belongs to the current step,
/// so the user can wander and the tutorial only advances on the action it asked for.
@MainActor
@Observable
final class DashboardTutorial {
    enum Step {
        case openSharing, returnFromSharing, previousDay, backToToday, expandRing, macros, done

        static let count = 4

        var displayIndex: Int {
            switch self {
            case .openSharing, .returnFromSharing: 1
            case .previousDay, .backToToday: 2
            case .expandRing: 3
            case .macros, .done: 4
            }
        }

        var target: TutorialTarget? {
            switch self {
            case .openSharing, .previousDay, .expandRing: .ringPanel
            case .backToToday: .todayPill
            case .macros: .legend
            case .returnFromSharing, .done: nil
            }
        }

        var spotlightShape: SpotlightShapeKind {
            switch target {
            case .legend: .roundedRect(22)
            case .todayPill: .capsule
            default: .circle
            }
        }

        /// Horizontal swipe direction the hand demonstrates: -1 left, 1 right, nil for taps.
        var swipeDirection: CGFloat? {
            switch self {
            case .openSharing: -1
            case .previousDay: 1
            default: nil
            }
        }

        var title: String {
            switch self {
            case .openSharing: "See your sharing circle"
            case .returnFromSharing: "Your sharing circle"
            case .previousDay: "Look back"
            case .backToToday: "Back to today"
            case .expandRing: "Tap for more"
            case .macros: "Focus on a macro"
            case .done: "You're all set"
            }
        }

        func message(nextMacro: MacroMetric?) -> String {
            switch self {
            case .openSharing: "Swipe left on your rings to open Sharing."
            case .returnFromSharing:
                "People who share with you show their rings here. Swipe right from the edge or tap Back to return."
            case .previousDay: "Swipe right on your rings to see yesterday."
            case .backToToday: "Tap Today to come back."
            case .expandRing: "Tap the rings to make them bigger and see more nutrition details."
            case .macros: "Tap \(nextMacro?.title ?? "a macro")."
            case .done: "Log your first food with Camera or Add Food."
            }
        }

        func actionTitle(nextMacro: MacroMetric?) -> String? {
            switch self {
            case .openSharing: "Open Sharing"
            case .previousDay: "Show Yesterday"
            case .backToToday: "Go to Today"
            case .expandRing: "Expand Rings"
            case .macros: nextMacro.map { "Select \($0.title)" }
            case .returnFromSharing: "Back to Dashboard"
            case .done: nil
            }
        }
    }

    private(set) var step: Step?
    private(set) var macrosTapped: Set<MacroMetric> = []
    private(set) var frames: [TutorialTarget: CGRect] = [:]
    /// Stored, so views that only need readiness are not invalidated by every frame write.
    private(set) var isDashboardReady = false
    /// Set by DashboardScreen while it is on screen: runs the current step's action.
    @ObservationIgnored var performAction: (() -> Void)?

    private static let readinessTargets: [TutorialTarget] = [.ringPanel, .legend, .contentArea, .bottomBar]

    func report(_ rect: CGRect, for target: TutorialTarget) {
        guard frames[target] != rect else { return }
        frames[target] = rect
        let isReady = Self.readinessTargets.allSatisfy { frames[$0].map { !$0.isEmpty } ?? false }
        if isReady != isDashboardReady { isDashboardReady = isReady }
    }

    var isRunning: Bool { step != nil }

    var nextMacro: MacroMetric? {
        MacroMetric.allCases.first { !macrosTapped.contains($0) }
    }

    func start() {
        guard step == nil else { return }
        macrosTapped = []
        step = .openSharing
    }

    func finish() {
        step = nil
    }

    func didOpenSharing() {
        advance(from: .openSharing, to: .returnFromSharing)
    }

    func didReturnToRoot() {
        advance(from: .returnFromSharing, to: .previousDay)
    }

    func didChangeDay(isToday: Bool) {
        if !isToday {
            advance(from: .previousDay, to: .backToToday)
        } else {
            advance(from: .backToToday, to: .expandRing)
        }
    }

    func didExpandRing() {
        advance(from: .expandRing, to: .macros)
    }

    func didSelectMacro(_ metric: MacroMetric) {
        guard step == .macros else { return }
        macrosTapped.insert(metric)
        if nextMacro == nil {
            step = .done
        }
    }

    private func advance(from current: Step, to next: Step) {
        guard step == current else { return }
        step = next
    }
}
