import SwiftUI

enum SpotlightShapeKind {
    case circle, roundedRect(CGFloat), capsule

    /// Circles hug the target's shorter side so a panel wider than its ring still gets a round cutout.
    func spotlight(around rect: CGRect) -> Spotlight {
        switch self {
        case .circle:
            let diameter = min(rect.width, rect.height) + 24
            return Spotlight(
                rect: CGRect(x: rect.midX - diameter / 2, y: rect.midY - diameter / 2, width: diameter, height: diameter),
                radius: diameter / 2)
        case let .roundedRect(radius):
            return Spotlight(rect: rect.insetBy(dx: -10, dy: -10), radius: radius)
        case .capsule:
            let padded = rect.insetBy(dx: -8, dy: -8)
            return Spotlight(rect: padded, radius: min(padded.width, padded.height) / 2)
        }
    }
}

/// A rounded rectangle; circles and capsules are the radius = min(w, h) / 2 case, so every shape morphs through one value.
struct Spotlight: Equatable {
    var rect: CGRect
    var radius: CGFloat

    static func collapsed(at point: CGPoint) -> Spotlight {
        Spotlight(rect: CGRect(origin: point, size: .zero), radius: 0)
    }

    func grown(by amount: CGFloat) -> Spotlight {
        Spotlight(rect: rect.insetBy(dx: -amount, dy: -amount), radius: radius + amount)
    }
}

struct SpotlightShape: Shape {
    var spotlight: Spotlight
    /// Fills everything except the cutout (with an even-odd fill); the rect is oversized so a blurred mask does not fade at the screen edges.
    var isInverted = false

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat>>
    {
        get {
            .init(
                .init(spotlight.rect.origin.x, spotlight.rect.origin.y),
                .init(.init(spotlight.rect.width, spotlight.rect.height), spotlight.radius))
        }
        set {
            spotlight = Spotlight(
                rect: CGRect(
                    x: newValue.first.first, y: newValue.first.second,
                    width: newValue.second.first.first, height: newValue.second.first.second),
                radius: newValue.second.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = isInverted ? Path(rect.insetBy(dx: -40, dy: -40)) : Path()
        path.addRoundedRect(
            in: spotlight.rect, cornerSize: CGSize(width: spotlight.radius, height: spotlight.radius), style: .continuous)
        return path
    }
}

struct DashboardTutorialOverlay: View {
    @Environment(DashboardTutorial.self) private var tutorial
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let step: DashboardTutorial.Step
    /// Global position of this overlay's top-left corner; tutorial frames are global.
    let origin: CGPoint
    let size: CGSize

    @State private var lastTargetRect: CGRect?
    @State private var isDismissing = false

    private let captionGap: CGFloat = 16

    private func localFrame(_ target: TutorialTarget) -> CGRect? {
        tutorial.frames[target]?.offsetBy(dx: -origin.x, dy: -origin.y)
    }

    private var targetRect: CGRect? { step.target.flatMap(localFrame) }

    private var spotlight: Spotlight {
        guard step.target != nil, let rect = targetRect ?? lastTargetRect else {
            return .collapsed(at: CGPoint(x: size.width / 2, y: size.height / 2))
        }
        return step.spotlightShape.spotlight(around: rect)
    }

    private var scrimOpacity: Double {
        let isDark = colorScheme == .dark
        if step == .done { return isDark ? 0.6 : 0.4 }
        return isDark ? 0.78 : 0.62
    }

    private var morph: Animation? { reduceMotion ? nil : .smooth(duration: 0.4) }

    var body: some View {
        let spotlight = spotlight

        ZStack {
            Group {
                Rectangle()
                    .fill(.black.opacity(scrimOpacity))
                    .mask {
                        SpotlightShape(spotlight: spotlight, isInverted: true)
                            .fill(style: FillStyle(eoFill: true))
                            .blur(radius: 3)
                    }
                    .contentShape(SpotlightShape(spotlight: spotlight, isInverted: true), eoFill: true)
                    .gesture(DragGesture(minimumDistance: 0))

                if step != .done {
                    focusRing(spotlight)
                }
            }
            .animation(morph, value: spotlight)
            .animation(morph, value: step == .done)
            .accessibilityHidden(true)

            if step != .done {
                TutorialHand(swipeDirection: step.swipeDirection, reduceMotion: reduceMotion)
                    .id(step)
                    .position(handPosition(in: spotlight.rect))
                    .allowsHitTesting(false)
                    .accessibilityRepresentation { EmptyView() }
                    .accessibilityHidden(true)
            }

            caption(cutout: spotlight.rect)
        }
        .opacity(isDismissing ? 0 : 1)
        .onChange(of: targetRect, initial: true) { _, rect in
            if let rect { lastTargetRect = rect }
        }
    }

    private func focusRing(_ spotlight: Spotlight) -> some View {
        ZStack {
            SpotlightShape(spotlight: spotlight)
                .stroke(.white.opacity(0.9), lineWidth: 2)
            if !reduceMotion {
                let halo = spotlight.grown(by: 0.03 * min(spotlight.rect.width, spotlight.rect.height))
                PhaseAnimator([false, true]) { expanded in
                    SpotlightShape(spotlight: expanded ? halo : spotlight)
                        .stroke(.white.opacity(expanded ? 0 : 0.25), lineWidth: 6)
                } animation: { expanded in
                    expanded ? .easeOut(duration: 1.6) : nil
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// The legend columns share its width equally, or stack vertically at accessibility sizes.
    private func handPosition(in cutout: CGRect) -> CGPoint {
        guard step == .macros, let next = tutorial.nextMacro, let index = MacroMetric.allCases.firstIndex(of: next)
        else { return CGPoint(x: cutout.midX, y: cutout.midY) }
        guard let targetRect else { return CGPoint(x: cutout.midX, y: cutout.midY) }
        let fraction = (CGFloat(index) + 0.5) / CGFloat(MacroMetric.allCases.count)
        if dynamicTypeSize.isAccessibilitySize {
            let stackedFraction = (CGFloat(index) + 0.8) / CGFloat(MacroMetric.allCases.count)
            return CGPoint(x: targetRect.midX, y: targetRect.minY + targetRect.height * stackedFraction)
        }
        return CGPoint(x: targetRect.minX + targetRect.width * fraction, y: targetRect.midY)
    }

    @ViewBuilder
    private func caption(cutout: CGRect) -> some View {
        let top = localFrame(.contentArea)?.minY ?? 0
        let bottom = localFrame(.bottomBar)?.minY ?? size.height
        let isFullHeight = step == .done || cutout.isEmpty
        let above = max(0, cutout.minY - top - captionGap)
        let below = max(0, bottom - cutout.maxY - captionGap)
        let placeBelow = below >= above
        let regionHeight =
            if isFullHeight {
                bottom - top
            } else {
                placeBelow ? below : above
            }
        let regionCenterY =
            if isFullHeight {
                (top + bottom) / 2
            } else {
                placeBelow ? cutout.maxY + captionGap + below / 2 : top + above / 2
            }
        ScrollView {
            ZStack {
                if step == .done {
                    TutorialDoneCard(onDone: dismiss)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.94).combined(with: .opacity))
                } else {
                    TutorialCaptionCard(step: step, onAction: { tutorial.performAction?() })
                }
            }
            .animation(.smooth(duration: 0.35), value: step == .done)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(isFullHeight ? .center : nil)
        .frame(height: regionHeight)
        .position(x: size.width / 2, y: regionCenterY)
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            isDismissing = true
        } completion: {
            tutorial.finish()
        }
    }
}

private struct TutorialHand: View {
    let swipeDirection: CGFloat?
    let reduceMotion: Bool

    private struct Frame {
        var opacity = 0.0
        var scale = 1.0
        var offset: Double
    }

    private var symbol: String { swipeDirection == nil ? "hand.tap.fill" : "hand.point.up.left.fill" }
    private let travelDistance: CGFloat = 120

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
            // The hand starts at the swipe's start point and only jumps back while fully invisible, so it
            // never appears to move against the swipe direction. Every track totals 2.2 s.
            let direction = swipeDirection ?? 0
            let travel = travelDistance * direction
            hand
                .keyframeAnimator(initialValue: Frame(offset: -travel / 2), repeating: true) { content, frame in
                    content
                        .scaleEffect(frame.scale)
                        .background { trail(frame: frame, direction: direction, travel: travel) }
                        .offset(x: frame.offset)
                        .opacity(frame.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(0, duration: 0.01)
                        LinearKeyframe(1, duration: 0.25)
                        LinearKeyframe(1, duration: 0.99)
                        LinearKeyframe(0, duration: 0.25)
                        LinearKeyframe(0, duration: 0.70)
                    }
                    KeyframeTrack(\.scale) {
                        LinearKeyframe(1, duration: 0.26)
                        CubicKeyframe(0.9, duration: 0.2)
                        LinearKeyframe(0.9, duration: 0.8)
                        CubicKeyframe(1, duration: 0.24)
                        LinearKeyframe(1, duration: 0.70)
                    }
                    KeyframeTrack(\.offset) {
                        LinearKeyframe(-travel / 2, duration: 0.45)
                        CubicKeyframe(travel / 2, duration: 0.80)
                        LinearKeyframe(travel / 2, duration: 0.30)
                        LinearKeyframe(-travel / 2, duration: 0.01)
                        LinearKeyframe(-travel / 2, duration: 0.64)
                    }
                }
        }
    }

    /// A fading streak between the swipe's start and the fingertip, brightest at the fingertip.
    @ViewBuilder
    private func trail(frame: Frame, direction: CGFloat, travel: CGFloat) -> some View {
        if direction != 0 {
            let width = abs(frame.offset + travel / 2)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0), .white.opacity(0.5)],
                        startPoint: direction > 0 ? .leading : .trailing,
                        endPoint: direction > 0 ? .trailing : .leading)
                )
                .frame(width: width, height: 8)
                .offset(x: (-travel / 2 - frame.offset) / 2)
                .allowsHitTesting(false)
        }
    }

    private var hand: some View {
        Image(systemName: symbol)
            .font(.system(size: 44))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
            .accessibilityHidden(true)
    }
}
