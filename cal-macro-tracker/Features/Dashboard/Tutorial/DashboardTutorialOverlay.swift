import SwiftUI

struct SpotlightShape: Shape {
    static let cornerRadius: CGFloat = 24

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
        path.addRoundedRect(in: cutout, cornerSize: CGSize(width: Self.cornerRadius, height: Self.cornerRadius))
        return path
    }
}

struct DashboardTutorialOverlay: View {
    @Environment(DashboardTutorial.self) private var tutorial
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    let step: DashboardTutorial.Step
    /// Global position of this overlay's top-left corner; tutorial frames are global.
    let origin: CGPoint
    let size: CGSize

    @State private var lastTargetRect: CGRect?

    private let cutoutInset: CGFloat = 12

    private func localFrame(_ target: TutorialTarget) -> CGRect? {
        tutorial.frames[target]?.offsetBy(dx: -origin.x, dy: -origin.y)
    }

    private var targetRect: CGRect? { step.target.flatMap(localFrame) }

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
                .fill(.black.opacity(colorScheme == .dark ? 0.72 : 0.55), style: FillStyle(eoFill: true))
                .contentShape(SpotlightShape(cutout: cutout), eoFill: true)
                .gesture(DragGesture(minimumDistance: 0))
                .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: cutout)
                .accessibilityHidden(true)

            if !cutout.isEmpty {
                RoundedRectangle(cornerRadius: SpotlightShape.cornerRadius)
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.9 : 0.8), lineWidth: 2)
                    .shadow(color: .white.opacity(colorScheme == .dark ? 0.45 : 0.25), radius: 8)
                    .frame(width: cutout.width, height: cutout.height)
                    .position(x: cutout.midX, y: cutout.midY)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: cutout)
            }

            if step != .done {
                TutorialHand(swipeDirection: step.swipeDirection, reduceMotion: reduceMotion)
                    .id(step)
                    .position(handPosition(in: cutout))
                    .allowsHitTesting(false)
                    .accessibilityRepresentation { EmptyView() }
                    .accessibilityHidden(true)
            }

            caption(cutout: cutout)
        }
        .onChange(of: targetRect, initial: true) { _, rect in
            if let rect { lastTargetRect = rect }
        }
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
        let card = TutorialCaptionCard(step: step, onAction: step == .done ? nil : { tutorial.performAction?() })
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        let top = localFrame(.contentArea)?.minY ?? 0
        let bottom = localFrame(.bottomBar)?.minY ?? size.height
        let isFullHeight = step == .done || cutout.isEmpty
        let above = max(0, cutout.minY - top - 12)
        let below = max(0, bottom - cutout.maxY - 12)
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
                placeBelow ? cutout.maxY + 12 + below / 2 : top + above / 2
            }
        ScrollView {
            card
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(isFullHeight ? .center : nil)
        .frame(height: regionHeight)
        .position(x: size.width / 2, y: regionCenterY)
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
            // The hand starts at the swipe's start point and only jumps back while fully invisible, so it
            // never appears to move against the swipe direction. Every track totals 2.2 s.
            let travel = 120 * (swipeDirection ?? 0)
            hand
                .keyframeAnimator(initialValue: Frame(offset: -travel / 2), repeating: true) { content, frame in
                    content
                        .scaleEffect(frame.scale)
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

    private var hand: some View {
        Image(systemName: symbol)
            .font(.system(size: 52))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
            .accessibilityHidden(true)
    }
}
