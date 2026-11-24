import SwiftUI

enum SpotlightShapeKind {
    case circle, roundedRect(CGFloat), capsule

    /// Circles hug the target's shorter side so a panel wider than its ring still gets a round cutout.
    func spotlight(around rect: CGRect) -> Spotlight {
        switch self {
        case .circle:
            let diameter = min(rect.width, rect.height) + 48
            return Spotlight(
                rect: CGRect(x: rect.midX - diameter / 2, y: rect.midY - diameter / 2, width: diameter, height: diameter),
                radius: diameter / 2)
        case let .roundedRect(radius):
            return Spotlight(rect: rect.insetBy(dx: -20, dy: -20), radius: radius)
        case .capsule:
            let padded = rect.insetBy(dx: -14, dy: -14)
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
    var onSkipStep: () -> Void = {}

    @State private var isVisible = false
    @State private var isDismissing = false
    @State private var captionTop: CGFloat?

    private var captionHeight: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return size.height * (step == .done ? 0.42 : 0.18)
        }
        return size.height * (step == .done ? 0.28 : 0.18)
    }

    private func localFrame(_ target: TutorialTarget) -> CGRect? {
        tutorial.frames[target]?.offsetBy(dx: -origin.x, dy: -origin.y)
    }

    private var bottomBarFrame: CGRect {
        localFrame(.bottomBar) ?? CGRect(x: 0, y: size.height - 68, width: size.width, height: 68)
    }

    private var targetRect: CGRect? {
        if step == .macros, let nextMacro = tutorial.nextMacro {
            return localFrame(.macro(nextMacro))
        }
        return step.target.flatMap(localFrame)
    }

    /// Collapsed until the current step's own target has a rect, so a previous target's rect is never reused.
    private var spotlight: Spotlight {
        guard let rect = targetRect, !rect.isEmpty else {
            return .collapsed(at: CGPoint(x: size.width / 2, y: size.height / 2))
        }
        return step.spotlightShape.spotlight(around: rect)
    }

    private var scrimOpacity: Double {
        let isDark = colorScheme == .dark
        if step == .done { return isDark ? 0.6 : 0.4 }
        return 0.8
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

                if step != .done, !spotlight.rect.isEmpty {
                    SpotlightShape(spotlight: spotlight)
                        .stroke(.white.opacity(0.9), lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            // Only a step change morphs; geometry updates within a step must track moving targets without lag.
            .animation(nil, value: step)
            .accessibilityHidden(true)

            if step != .done, !spotlight.rect.isEmpty {
                TutorialHand(
                    swipeDirection: step.swipeDirection,
                    reduceMotion: reduceMotion || dynamicTypeSize.isAccessibilitySize || step.swipeDirection == nil
                )
                .id(step)
                .position(handPosition(in: spotlight.rect))
                .allowsHitTesting(false)
                // Both are intentional: the representation mask alone left the hand focusable (device-verified in 7053578).
                .accessibilityRepresentation { EmptyView() }
                .accessibilityHidden(true)
            }

            fixedTutorialLayout
        }
        .opacity(isDismissing || !isVisible ? 0 : 1)
        .onAppear {
            updateCaptionPosition()
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { isVisible = true }
        }
        .onChange(of: step) { _, _ in updateCaptionPosition() }
        .sensoryFeedback(.success, trigger: step == .done)
        .animation(
            reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.42, dampingFraction: 0.84),
            value: step == .done
        )
    }

    private func updateCaptionPosition() {
        let legendBottom = localFrame(.legend)?.maxY ?? size.height * 0.45
        let bottomBarTop = localFrame(.bottomBar)?.minY ?? size.height - 168
        if dynamicTypeSize.isAccessibilitySize {
            captionTop =
                step == .done
                ? min(size.height * 0.38, bottomBarTop - captionHeight - 24)
                : size.height * 0.6
        } else {
            captionTop = min(max(legendBottom + 80, size.height * 0.56), bottomBarTop - captionHeight - 24)
        }
    }

    private func handPosition(in cutout: CGRect) -> CGPoint {
        guard step == .macros, tutorial.nextMacro != nil else { return CGPoint(x: cutout.midX, y: cutout.midY) }
        guard let targetRect else { return CGPoint(x: cutout.midX, y: cutout.midY) }
        if dynamicTypeSize.isAccessibilitySize {
            return CGPoint(x: targetRect.midX, y: targetRect.maxY - min(140, targetRect.height * 0.24))
        }
        return CGPoint(x: targetRect.midX, y: targetRect.midY)
    }

    private var fixedTutorialLayout: some View {
        ZStack(alignment: .bottom) {
            if step != .done {
                BottomPinnedDualActionBar(
                    leadingAction: BottomPinnedDualAction(
                        title: "Skip Tutorial",
                        systemImage: "xmark",
                        action: dismiss,
                        tint: .gray
                    ),
                    trailingAction: BottomPinnedDualAction(
                        title: "Skip Step",
                        systemImage: "forward.end",
                        action: skipStep
                    ),
                    displayMode: .expanded,
                    compactActionsAreHorizontal: true,
                    topPadding: 0,
                    bottomOffset: 6,
                    edgeFadeColor: .clear
                )
                .frame(maxWidth: .infinity)
                .position(x: bottomBarFrame.midX, y: bottomBarFrame.midY)
                .transition(.opacity)
            }

            ScrollView {
                TutorialCaptionCard(step: step, onDone: dismiss)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .frame(height: captionHeight)
            .clipShape(Rectangle())
            .position(x: size.width / 2, y: (captionTop ?? size.height * 0.56) + captionHeight / 2)
        }
        .frame(width: size.width, height: size.height, alignment: .bottom)
        .ignoresSafeArea()
    }

    private func skipStep() {
        if step == .returnFromSharing {
            onSkipStep()
        } else {
            withAnimation(morph) { tutorial.skipStep() }
        }
    }

    private func dismiss() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
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
