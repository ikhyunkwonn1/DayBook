import AppKit
import SwiftUI

enum EditorialPalette {
    static let paper = Color(red: 0.969, green: 0.969, blue: 0.949)
    static let paperSoft = Color(red: 0.945, green: 0.945, blue: 0.922)
    static let ink = Color(red: 0.157, green: 0.153, blue: 0.125)
    static let inkSoft = Color(red: 0.43, green: 0.426, blue: 0.39)
    static let muted = Color(red: 0.52, green: 0.518, blue: 0.486)
    static let rule = Color(red: 0.865, green: 0.865, blue: 0.835)

    static let coral = Color(red: 0.922, green: 0.478, blue: 0.329)
    static let green = Color(red: 0.294, green: 0.616, blue: 0.388)
    static let gold = Color(red: 0.667, green: 0.604, blue: 0.176)
    static let lilac = Color(red: 0.608, green: 0.588, blue: 0.863)
    static let blue = Color(red: 0.239, green: 0.388, blue: 0.933)
    static let peach = Color(red: 0.835, green: 0.647, blue: 0.561)
    static let warning = Color(red: 0.92, green: 0.79, blue: 0.49)
}

struct EditorialBackdrop: View {
    var body: some View {
        EditorialPalette.paper
            .ignoresSafeArea()
    }
}

struct EditorialRule: View {
    var body: some View {
        Rectangle()
            .fill(EditorialPalette.rule)
            .frame(height: 1)
    }
}

struct EditorialScanlines: View {
    var body: some View {
        Canvas { context, size in
            var y = 0.0
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(rect), with: .color(.white.opacity(0.44)))
                y += 4
            }
        }
        .allowsHitTesting(false)
    }
}

struct EditorialHeroArt: NSViewRepresentable {
    func makeNSView(context: Context) -> EditorialHeroLayerView {
        EditorialHeroLayerView()
    }

    func updateNSView(_ nsView: EditorialHeroLayerView, context: Context) { }
}

final class EditorialHeroLayerView: NSView {
    private let lineSpecs = HeroLineSpec.all
    private var lineLayers: [CAShapeLayer] = []
    private var trackingArea: NSTrackingArea?
    private var isAnimating = false

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isGeometryFlipped = true
        layer?.masksToBounds = false
        createLineLayers()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        updateLinePaths()
        updateContentsScale()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        startHoverAnimation()
    }

    override func mouseExited(with event: NSEvent) {
        stopHoverAnimation()
    }

    private func createLineLayers() {
        guard let hostLayer = layer else { return }

        lineLayers = lineSpecs.map { spec in
            let lineLayer = CAShapeLayer()
            lineLayer.fillColor = NSColor.clear.cgColor
            lineLayer.strokeColor = spec.color.cgColor
            lineLayer.lineWidth = 2.3
            lineLayer.lineCap = .round
            lineLayer.lineJoin = .round
            lineLayer.allowsEdgeAntialiasing = true
            hostLayer.addSublayer(lineLayer)
            return lineLayer
        }
    }

    private func updateLinePaths() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let scale = min(bounds.width / 1_400, bounds.height / 280)
        let inset = CGPoint(
            x: (bounds.width - 1_400 * scale) / 2,
            y: (bounds.height - 280 * scale) / 2
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (spec, lineLayer) in zip(lineSpecs, lineLayers) {
            lineLayer.frame = bounds
            lineLayer.path = makePath(from: spec.points, scale: scale, inset: inset)
        }
        CATransaction.commit()
    }

    private func updateContentsScale() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        layer?.contentsScale = scale
        lineLayers.forEach { $0.contentsScale = scale }
    }

    private func startHoverAnimation() {
        guard !isAnimating, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        isAnimating = true

        for (spec, lineLayer) in zip(lineSpecs, lineLayers) {
            lineLayer.removeAnimation(forKey: "editorial.hero.settle")

            let animation = CAKeyframeAnimation(keyPath: "transform")
            let direction = spec.direction
            let midpoint = CATransform3DRotate(
                CATransform3DMakeTranslation(spec.travel * direction, spec.verticalTravel, 0),
                spec.rotation * direction,
                0,
                0,
                1
            )
            let returnPoint = CATransform3DRotate(
                CATransform3DMakeTranslation(-spec.travel * direction * 0.55, -spec.verticalTravel * 0.35, 0),
                -spec.rotation * direction * 0.45,
                0,
                0,
                1
            )

            animation.values = [
                NSValue(caTransform3D: CATransform3DIdentity),
                NSValue(caTransform3D: midpoint),
                NSValue(caTransform3D: returnPoint),
                NSValue(caTransform3D: CATransform3DIdentity)
            ]
            animation.keyTimes = [0, 0.38, 0.72, 1]
            animation.timingFunctions = [
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeInEaseOut)
            ]
            animation.duration = spec.duration
            animation.beginTime = CACurrentMediaTime() + spec.delay
            animation.repeatCount = .infinity
            lineLayer.add(animation, forKey: "editorial.hero.hover")
        }
    }

    private func stopHoverAnimation() {
        guard isAnimating else { return }
        isAnimating = false

        for lineLayer in lineLayers {
            guard let presentationLayer = lineLayer.presentation() else {
                lineLayer.removeAnimation(forKey: "editorial.hero.hover")
                continue
            }

            let currentTransform = presentationLayer.transform
            let settle = CABasicAnimation(keyPath: "transform")
            settle.fromValue = NSValue(caTransform3D: currentTransform)
            settle.toValue = NSValue(caTransform3D: CATransform3DIdentity)
            settle.duration = 0.26
            settle.timingFunction = CAMediaTimingFunction(name: .easeOut)

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            lineLayer.removeAnimation(forKey: "editorial.hero.hover")
            lineLayer.transform = CATransform3DIdentity
            lineLayer.add(settle, forKey: "editorial.hero.settle")
            CATransaction.commit()
        }
    }

    private func makePath(from points: [CGPoint], scale: CGFloat, inset: CGPoint) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }

        path.move(to: transformed(first, scale: scale, inset: inset))
        for index in stride(from: 1, to: points.count - 2, by: 3) {
            path.addCurve(
                to: transformed(points[index + 2], scale: scale, inset: inset),
                control1: transformed(points[index], scale: scale, inset: inset),
                control2: transformed(points[index + 1], scale: scale, inset: inset)
            )
        }
        return path
    }

    private func transformed(_ point: CGPoint, scale: CGFloat, inset: CGPoint) -> CGPoint {
        CGPoint(x: inset.x + point.x * scale, y: inset.y + point.y * scale)
    }
}

private struct HeroLineSpec {
    let color: NSColor
    let points: [CGPoint]
    let travel: CGFloat
    let verticalTravel: CGFloat
    let rotation: CGFloat
    let duration: CFTimeInterval
    let delay: CFTimeInterval
    let direction: CGFloat

    static let all: [HeroLineSpec] = [
        .init(
            color: .systemOrange,
            points: [
                .init(x: 32, y: 149), .init(x: 48, y: 64), .init(x: 235, y: 53), .init(x: 260, y: 85),
                .init(x: 287, y: 120), .init(x: 77, y: 179), .init(x: 214, y: 212),
                .init(x: 293, y: 231), .init(x: 305, y: 175), .init(x: 261, y: 143)
            ],
            travel: 7, verticalTravel: 1, rotation: 0.003, duration: 4.8, delay: 0, direction: 1
        ),
        .init(
            color: .systemGreen,
            points: [
                .init(x: 195, y: 211), .init(x: 184, y: 134), .init(x: 276, y: 38), .init(x: 378, y: 62),
                .init(x: 455, y: 81), .init(x: 339, y: 214), .init(x: 215, y: 208)
            ],
            travel: 5, verticalTravel: -2, rotation: 0.004, duration: 5.6, delay: 0.08, direction: -1
        ),
        .init(
            color: NSColor(red: 0.67, green: 0.60, blue: 0.18, alpha: 1),
            points: [
                .init(x: 360, y: 60), .init(x: 398, y: 25), .init(x: 383, y: 237), .init(x: 456, y: 213),
                .init(x: 510, y: 195), .init(x: 543, y: 9), .init(x: 572, y: 64),
                .init(x: 605, y: 127), .init(x: 488, y: 249), .init(x: 428, y: 204)
            ],
            travel: 6, verticalTravel: 2, rotation: 0.004, duration: 4.4, delay: 0.16, direction: 1
        ),
        .init(
            color: NSColor(red: 0.61, green: 0.59, blue: 0.86, alpha: 1),
            points: [
                .init(x: 566, y: 148), .init(x: 589, y: 42), .init(x: 704, y: 52), .init(x: 746, y: 108),
                .init(x: 786, y: 165), .init(x: 729, y: 228), .init(x: 662, y: 195),
                .init(x: 587, y: 159), .init(x: 674, y: 15), .init(x: 744, y: 59),
                .init(x: 812, y: 103), .init(x: 754, y: 205), .init(x: 696, y: 211)
            ],
            travel: 8, verticalTravel: -1, rotation: 0.005, duration: 5.2, delay: 0.04, direction: -1
        ),
        .init(
            color: NSColor(red: 0.16, green: 0.15, blue: 0.13, alpha: 1),
            points: [
                .init(x: 705, y: 212), .init(x: 741, y: 154), .init(x: 805, y: 81), .init(x: 846, y: 62),
                .init(x: 892, y: 41), .init(x: 738, y: 254), .init(x: 708, y: 213)
            ],
            travel: 5, verticalTravel: 2, rotation: 0.004, duration: 4.7, delay: 0.2, direction: 1
        ),
        .init(
            color: NSColor(red: 0.84, green: 0.65, blue: 0.56, alpha: 1),
            points: [
                .init(x: 824, y: 182), .init(x: 849, y: 142), .init(x: 935, y: 71), .init(x: 951, y: 79),
                .init(x: 971, y: 89), .init(x: 879, y: 152), .init(x: 878, y: 181),
                .init(x: 877, y: 214), .init(x: 1_044, y: 213), .init(x: 1_076, y: 183),
                .init(x: 1_098, y: 162), .init(x: 949, y: 215), .init(x: 829, y: 182)
            ],
            travel: 7, verticalTravel: -2, rotation: 0.003, duration: 5.4, delay: 0.12, direction: -1
        ),
        .init(
            color: NSColor(red: 0.24, green: 0.39, blue: 0.93, alpha: 1),
            points: [
                .init(x: 1_021, y: 89), .init(x: 1_070, y: 64), .init(x: 1_245, y: 55), .init(x: 1_278, y: 66),
                .init(x: 1_312, y: 77), .init(x: 1_082, y: 96), .init(x: 1_071, y: 116),
                .init(x: 1_055, y: 143), .init(x: 1_277, y: 164), .init(x: 1_279, y: 203),
                .init(x: 1_281, y: 230), .init(x: 1_124, y: 213), .init(x: 1_032, y: 212)
            ],
            travel: 8, verticalTravel: 1, rotation: 0.004, duration: 4.9, delay: 0.24, direction: 1
        )
    ]
}

struct EditorialPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium, design: .default))
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .foregroundStyle(EditorialPalette.paper)
            .background(EditorialPalette.ink.opacity(configuration.isPressed ? 0.82 : 1))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct EditorialTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium, design: .default))
            .foregroundStyle(configuration.isPressed ? EditorialPalette.inkSoft : EditorialPalette.ink)
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
    }
}

struct EditorialIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .regular, design: .default))
            .foregroundStyle(configuration.isPressed ? EditorialPalette.muted : EditorialPalette.ink)
            .frame(width: 30, height: 30)
    }
}

struct EditorialTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 13, weight: .regular, design: .default))
            .padding(.vertical, 9)
            .padding(.horizontal, 2)
            .background(alignment: .bottom) {
                EditorialRule()
            }
    }
}
