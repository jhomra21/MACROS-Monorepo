import SwiftUI

struct SpotlightShape: Shape {
    var cutout: CGRect

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { .init(.init(cutout.origin.x, cutout.origin.y), .init(cutout.size.width, cutout.size.height)) }
        set {
            cutout = CGRect(
                x: newValue.first.first, y: newValue.first.second,
                width: newValue.second.first, height: newValue.second.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRoundedRect(in: cutout, cornerSize: CGSize(width: 24, height: 24))
        return path
    }
}

struct DashboardTutorialOverlay: View {
    @Environment(DashboardTutorial.self) private var tutorial
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let step: DashboardTutorial.Step
    let targetRect: CGRect?
    let size: CGSize
    let onAction: () -> Void

    @State private var lastTargetRect: CGRect?

    private let cutoutInset: CGFloat = 12
    private let cardClearance: CGFloat = 190

    private var cutout: CGRect {
        guard step.target != nil, let rect = targetRect ?? lastTargetRect else {
            return CGRect(x: size.width / 2, y: size.height / 2, width: 0, height: 0)
        }
        // Swipe steps get the full screen width so there is room to drag.
        let base = step.swipeDirection == nil ? rect : CGRect(x: 0, y: rect.minY, width: size.width, height: rect.height)
        return base.insetBy(dx: -cutoutInset, dy: -cutoutInset)
    }

    var body: some View {
        let cutout = cutout

        ZStack {
            SpotlightShape(cutout: cutout)
                .fill(.black.opacity(0.55), style: FillStyle(eoFill: true))
                .contentShape(SpotlightShape(cutout: cutout), eoFill: true)
                .gesture(DragGesture(minimumDistance: 0))
                .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: cutout)
                .accessibilityHidden(true)

            if step != .done {
                TutorialHand(swipeDirection: step.swipeDirection, reduceMotion: reduceMotion)
                    .id(step)
                    .position(x: handX(in: cutout), y: cutout.midY)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            caption(cutout: cutout)
        }
        .onChange(of: targetRect, initial: true) { _, rect in
            if let rect { lastTargetRect = rect }
        }
    }

    /// The legend columns share its width equally, so the hand sits over the next untapped macro.
    private func handX(in cutout: CGRect) -> CGFloat {
        guard step == .macros, let next = tutorial.nextMacro, let index = MacroMetric.allCases.firstIndex(of: next)
        else { return cutout.midX }
        let columnWidth = (cutout.width - 2 * cutoutInset) / CGFloat(MacroMetric.allCases.count)
        return cutout.minX + cutoutInset + columnWidth * (CGFloat(index) + 0.5)
    }

    @ViewBuilder
    private func caption(cutout: CGRect) -> some View {
        let card = TutorialCaptionCard(step: step, onAction: step == .done ? nil : onAction)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)

        if step == .done || cutout.isEmpty {
            card
        } else if size.height - cutout.maxY >= cardClearance {
            card
                .padding(.top, cutout.maxY + 12)
                .frame(maxHeight: .infinity, alignment: .top)
        } else {
            card
                .padding(.bottom, size.height - cutout.minY + 12)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

private struct TutorialHand: View {
    let swipeDirection: CGFloat?
    let reduceMotion: Bool

    private struct Frame {
        var opacity = 0.0
        var scale = 1.0
        var offset = 0.0
    }

    private var symbol: String { swipeDirection == nil ? "hand.tap.fill" : "hand.draw.fill" }

    var body: some View {
        if reduceMotion {
            VStack(spacing: 8) {
                if let swipeDirection {
                    Image(systemName: swipeDirection < 0 ? "arrow.left" : "arrow.right")
                }
                hand
            }
            .font(.system(size: 36, weight: .semibold))
            .foregroundStyle(.white)
        } else {
            hand
                .keyframeAnimator(initialValue: Frame(), repeating: true) { content, frame in
                    content
                        .scaleEffect(frame.scale)
                        .offset(x: frame.offset)
                        .opacity(frame.opacity)
                } keyframes: { _ in
                    let travel = 120 * (swipeDirection ?? 0)
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(0, duration: 0.01)
                        LinearKeyframe(1, duration: 0.25)
                        LinearKeyframe(1, duration: 1.0)
                        LinearKeyframe(0, duration: 0.25)
                        LinearKeyframe(0, duration: 0.69)
                    }
                    KeyframeTrack(\.scale) {
                        LinearKeyframe(1, duration: 0.25)
                        CubicKeyframe(0.9, duration: 0.2)
                        LinearKeyframe(0.9, duration: 0.8)
                        CubicKeyframe(1, duration: 0.2)
                        LinearKeyframe(1, duration: 0.75)
                    }
                    KeyframeTrack(\.offset) {
                        LinearKeyframe(-travel / 2, duration: 0.45)
                        CubicKeyframe(travel / 2, duration: 0.8)
                        LinearKeyframe(travel / 2, duration: 0.2)
                        LinearKeyframe(-travel / 2, duration: 0.01)
                        LinearKeyframe(-travel / 2, duration: 0.74)
                    }
                }
        }
    }

    private var hand: some View {
        Image(systemName: symbol)
            .font(.system(size: 52))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
            .accessibilityHidden(true)
    }
}
