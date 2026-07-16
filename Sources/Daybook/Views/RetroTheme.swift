import AppKit
import SwiftUI

enum EditorialPalette {
    static let paper = Color(red: 0.969, green: 0.969, blue: 0.949)
    static let paperSoft = Color(red: 0.945, green: 0.945, blue: 0.922)
    static let ink = Color(red: 0.157, green: 0.153, blue: 0.125)
    static let inkSoft = Color(red: 0.43, green: 0.426, blue: 0.39)
    static let muted = Color(red: 0.52, green: 0.518, blue: 0.486)
    static let rule = Color(red: 0.865, green: 0.865, blue: 0.835)

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
    private var lineCenters: [CGPoint] = []
    private var amplitudes: [CGFloat]
    private var trackingArea: NSTrackingArea?

    private var driftLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var cursor: CGPoint?
    private var scale: CGFloat = 1
    private var didPlayEntrance = false

    // Falloff radius, in the 1400×280 artwork coordinate space.
    private let falloffRadius: CGFloat = 320
    // How quickly a scribble's sway amplitude chases its proximity target.
    private let easeRate: Double = 6
    private let drawInDuration: CFTimeInterval = 0.85
    private let drawInStagger: CFTimeInterval = 0.13

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        amplitudes = Array(repeating: 0, count: lineSpecs.count)
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isGeometryFlipped = true
        layer?.masksToBounds = false
        createLineLayers()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // The display link retains this view, so tear it down when detached to avoid a leak.
        if window == nil {
            stopDriftLink()
        }
    }

    override func layout() {
        super.layout()
        updateLinePaths()
        updateContentsScale()

        if !didPlayEntrance, bounds.width > 0, bounds.height > 0 {
            didPlayEntrance = true
            playEntrance()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        updateCursor(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        cursor = nil
    }

    private func updateCursor(with event: NSEvent) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        cursor = convert(event.locationInWindow, from: nil)
        startDriftLink()
    }

    private func createLineLayers() {
        guard let hostLayer = layer else { return }

        lineLayers = lineSpecs.map { spec in
            let lineLayer = CAShapeLayer()
            lineLayer.fillColor = NSColor.clear.cgColor
            lineLayer.strokeColor = spec.color.cgColor
            lineLayer.lineWidth = 2.35
            lineLayer.lineCap = .round
            lineLayer.lineJoin = .round
            lineLayer.strokeEnd = 0
            lineLayer.allowsEdgeAntialiasing = true
            hostLayer.addSublayer(lineLayer)
            return lineLayer
        }
        lineCenters = Array(repeating: .zero, count: lineSpecs.count)
    }

    private func updateLinePaths() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        scale = min(bounds.width / 1_400, bounds.height / 280)
        let inset = CGPoint(
            x: (bounds.width - 1_400 * scale) / 2,
            y: (bounds.height - 280 * scale) / 2
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, spec) in lineSpecs.enumerated() {
            let lineLayer = lineLayers[index]
            lineLayer.frame = bounds
            let path = makePath(from: spec.points, scale: scale, inset: inset)
            lineLayer.path = path
            let box = path.boundingBox
            lineCenters[index] = CGPoint(x: box.midX, y: box.midY)
        }
        CATransaction.commit()
    }

    private func updateContentsScale() {
        let contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        layer?.contentsScale = contentsScale
        lineLayers.forEach { $0.contentsScale = contentsScale }
    }

    // Draws each scribble in once, stroke start to end, staggered like a hand sketching them.
    private func playEntrance() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            lineLayers.forEach { $0.strokeEnd = 1 }
            return
        }

        let timing = CAMediaTimingFunction(controlPoints: 0.3, 0.1, 0.3, 1)
        let start = CACurrentMediaTime()
        for (index, lineLayer) in lineLayers.enumerated() {
            lineLayer.strokeEnd = 1
            let draw = CABasicAnimation(keyPath: "strokeEnd")
            draw.fromValue = 0
            draw.toValue = 1
            draw.duration = drawInDuration
            draw.beginTime = start + Double(index) * drawInStagger
            draw.timingFunction = timing
            draw.fillMode = .backwards
            lineLayer.add(draw, forKey: "editorial.hero.draw")
        }
    }

    private func startDriftLink() {
        guard driftLink == nil else { return }
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }

        let link = displayLink(target: self, selector: #selector(stepDrift(_:)))
        lastTimestamp = 0
        link.add(to: .main, forMode: .common)
        driftLink = link
    }

    private func stopDriftLink() {
        driftLink?.invalidate()
        driftLink = nil
    }

    @objc private func stepDrift(_ link: CADisplayLink) {
        let now = link.timestamp
        if lastTimestamp == 0 { lastTimestamp = now }
        let dt = min(now - lastTimestamp, 0.05)
        lastTimestamp = now

        let ease = CGFloat(1 - exp(-dt * easeRate))
        let radius = falloffRadius * scale
        let anchorX = bounds.width / 2
        let anchorY = bounds.height / 2
        var maxAmp: CGFloat = 0

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, spec) in lineSpecs.enumerated() {
            var target: CGFloat = 0
            if let cursor, radius > 0 {
                let center = lineCenters[index]
                let distance = hypot(cursor.x - center.x, cursor.y - center.y)
                let u = max(0, min(1, 1 - distance / radius))
                target = u * u * (3 - 2 * u)
            }
            amplitudes[index] += (target - amplitudes[index]) * ease
            let amp = amplitudes[index]
            maxAmp = max(maxAmp, amp)

            let lineLayer = lineLayers[index]
            if amp < 0.001 {
                if !CATransform3DIsIdentity(lineLayer.transform) {
                    lineLayer.transform = CATransform3DIdentity
                }
                continue
            }

            let dx = CGFloat(sin(now * spec.wx + spec.px)) * spec.tx * scale * amp
            let dy = CGFloat(sin(now * spec.wy + spec.py)) * spec.ty * scale * amp
            let radians = CGFloat(sin(now * spec.wr + spec.pr)) * spec.rot * amp * .pi / 180

            // Rotate about the scribble's own center rather than the view center.
            let center = lineCenters[index]
            let pivotX = center.x - anchorX
            let pivotY = center.y - anchorY

            var transform = CATransform3DMakeTranslation(dx, dy, 0)
            transform = CATransform3DTranslate(transform, pivotX, pivotY, 0)
            transform = CATransform3DRotate(transform, radians, 0, 0, 1)
            transform = CATransform3DTranslate(transform, -pivotX, -pivotY, 0)
            lineLayer.transform = transform
        }
        CATransaction.commit()

        if cursor == nil, maxAmp < 0.001 {
            stopDriftLink()
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
    // Sway amplitudes: tx/ty in artwork units, rot in degrees.
    let tx: CGFloat
    let ty: CGFloat
    let rot: CGFloat
    // Angular frequencies (rad/s), derived from incommensurate periods so no two lines sync.
    let wx: Double
    let wy: Double
    let wr: Double
    // Phase offsets (rad).
    let px: Double
    let py: Double
    let pr: Double

    init(
        color: NSColor,
        points: [CGPoint],
        tx: CGFloat, ty: CGFloat, rot: CGFloat,
        periodX: Double, periodY: Double, periodRot: Double,
        phaseX: Double, phaseY: Double, phaseRot: Double
    ) {
        self.color = color
        self.points = points
        self.tx = tx
        self.ty = ty
        self.rot = rot
        self.wx = 2 * .pi / periodX
        self.wy = 2 * .pi / periodY
        self.wr = 2 * .pi / periodRot
        self.px = phaseX
        self.py = phaseY
        self.pr = phaseRot
    }

    // Active artwork. Point at `originalScribbles` to restore the meaningless set.
    static let all: [HeroLineSpec] = moments

    // "moments" — each scribble carries one letter's abstract essence (m·o·m·e·n·t·s):
    // a rhythm, an enclosure, a crossing, a reversal — never the letter's silhouette.
    // Geometry matches word-scribbles-preview.html, verified blind-illegible.
    static let moments: [HeroLineSpec] = [
        // m — a loose loop whose tail ripples in three soft beats
        .init(
            color: NSColor(red: 0.922, green: 0.478, blue: 0.329, alpha: 1),
            points: [
                .init(x: 60, y: 150), .init(x: 78, y: 64), .init(x: 210, y: 50), .init(x: 248, y: 96),
                .init(x: 278, y: 140), .init(x: 118, y: 168), .init(x: 96, y: 204),
                .init(x: 122, y: 232), .init(x: 138, y: 196), .init(x: 162, y: 214),
                .init(x: 186, y: 232), .init(x: 202, y: 196), .init(x: 226, y: 214),
                .init(x: 250, y: 232), .init(x: 272, y: 198), .init(x: 292, y: 178)
            ],
            tx: 7, ty: 2.4, rot: 1.3,
            periodX: 9.2, periodY: 7.4, periodRot: 11.0,
            phaseX: 0.3, phaseY: 1.7, phaseRot: 4.8
        ),
        // o — an egg-shaped enclosure, opening widened so it stays a gesture, not a letter
        .init(
            color: NSColor(red: 0.294, green: 0.616, blue: 0.388, alpha: 1),
            points: [
                .init(x: 228, y: 120), .init(x: 268, y: 58), .init(x: 368, y: 54), .init(x: 408, y: 116),
                .init(x: 434, y: 178), .init(x: 330, y: 236), .init(x: 264, y: 196),
                .init(x: 236, y: 176), .init(x: 240, y: 152), .init(x: 262, y: 138)
            ],
            tx: 5, ty: 3.1, rot: 1.6,
            periodX: 10.6, periodY: 8.8, periodRot: 8.4,
            phaseX: 2.1, phaseY: 0.4, phaseRot: 2.9
        ),
        // m — repetition softened to two rounded crests and a small end curl
        .init(
            color: NSColor(red: 0.667, green: 0.604, blue: 0.176, alpha: 1),
            points: [
                .init(x: 368, y: 196), .init(x: 388, y: 84), .init(x: 420, y: 52), .init(x: 448, y: 120),
                .init(x: 472, y: 182), .init(x: 494, y: 198), .init(x: 512, y: 148),
                .init(x: 528, y: 104), .init(x: 556, y: 112), .init(x: 568, y: 158),
                .init(x: 574, y: 196), .init(x: 542, y: 202), .init(x: 536, y: 164)
            ],
            tx: 8, ty: 2.0, rot: 1.1,
            periodX: 8.2, periodY: 6.4, periodRot: 9.6,
            phaseX: 4.4, phaseY: 3.1, phaseRot: 0.7
        ),
        // e — a two-loop chain; the first loop's stroke passes under itself
        .init(
            color: NSColor(red: 0.608, green: 0.588, blue: 0.863, alpha: 1),
            points: [
                .init(x: 578, y: 170), .init(x: 598, y: 78), .init(x: 688, y: 62), .init(x: 714, y: 124),
                .init(x: 730, y: 178), .init(x: 646, y: 196), .init(x: 628, y: 142),
                .init(x: 640, y: 84), .init(x: 726, y: 64), .init(x: 762, y: 116),
                .init(x: 788, y: 168), .init(x: 724, y: 210), .init(x: 688, y: 178)
            ],
            tx: 6, ty: 3.4, rot: 1.4,
            periodX: 11.8, periodY: 9.8, periodRot: 7.8,
            phaseX: 1.2, phaseY: 5.0, phaseRot: 3.9
        ),
        // n — a single rise-and-fall: a breaking-wave sweep whose descent folds back inward
        .init(
            color: NSColor(red: 0.157, green: 0.153, blue: 0.125, alpha: 1),
            points: [
                .init(x: 716, y: 206), .init(x: 744, y: 128), .init(x: 792, y: 84), .init(x: 838, y: 76),
                .init(x: 882, y: 70), .init(x: 850, y: 150), .init(x: 814, y: 198)
            ],
            tx: 5, ty: 2.2, rot: 1.7,
            periodX: 9.8, periodY: 7.8, periodRot: 10.4,
            phaseX: 5.3, phaseY: 2.6, phaseRot: 1.5
        ),
        // t — a long lazy sweep whose return pass drops through it: one quiet crossing
        .init(
            color: NSColor(red: 0.835, green: 0.647, blue: 0.561, alpha: 1),
            points: [
                .init(x: 836, y: 178), .init(x: 896, y: 148), .init(x: 1_004, y: 136), .init(x: 1_064, y: 158),
                .init(x: 1_096, y: 170), .init(x: 1_088, y: 120), .init(x: 1_044, y: 110),
                .init(x: 988, y: 98), .init(x: 938, y: 132), .init(x: 930, y: 196),
                .init(x: 928, y: 238), .init(x: 960, y: 242), .init(x: 976, y: 212)
            ],
            tx: 7, ty: 2.9, rot: 1.2,
            periodX: 11.2, periodY: 9.4, periodRot: 8.9,
            phaseX: 3.7, phaseY: 4.2, phaseRot: 5.7
        ),
        // s — a wide ribbon that reverses direction twice
        .init(
            color: NSColor(red: 0.239, green: 0.388, blue: 0.933, alpha: 1),
            points: [
                .init(x: 1_044, y: 90), .init(x: 1_108, y: 58), .init(x: 1_206, y: 62), .init(x: 1_258, y: 94),
                .init(x: 1_296, y: 122), .init(x: 1_264, y: 158), .init(x: 1_204, y: 162),
                .init(x: 1_144, y: 166), .init(x: 1_076, y: 178), .init(x: 1_060, y: 212),
                .init(x: 1_092, y: 246), .init(x: 1_176, y: 240), .init(x: 1_240, y: 214)
            ],
            tx: 8, ty: 2.6, rot: 1.5,
            periodX: 8.8, periodY: 7.0, periodRot: 10.9,
            phaseX: 0.9, phaseY: 1.1, phaseRot: 2.3
        )
    ]

    // The original abstract scribbles, kept for rollback and future daily shuffling.
    static let originalScribbles: [HeroLineSpec] = [
        .init(
            color: NSColor(red: 0.922, green: 0.478, blue: 0.329, alpha: 1),
            points: [
                .init(x: 32, y: 149), .init(x: 48, y: 64), .init(x: 235, y: 53), .init(x: 260, y: 85),
                .init(x: 287, y: 120), .init(x: 77, y: 179), .init(x: 214, y: 212),
                .init(x: 293, y: 231), .init(x: 305, y: 175), .init(x: 261, y: 143)
            ],
            tx: 7, ty: 2.4, rot: 1.3,
            periodX: 9.2, periodY: 7.4, periodRot: 11.0,
            phaseX: 0.3, phaseY: 1.7, phaseRot: 4.8
        ),
        .init(
            color: NSColor(red: 0.294, green: 0.616, blue: 0.388, alpha: 1),
            points: [
                .init(x: 195, y: 211), .init(x: 184, y: 134), .init(x: 276, y: 38), .init(x: 378, y: 62),
                .init(x: 455, y: 81), .init(x: 339, y: 214), .init(x: 215, y: 208)
            ],
            tx: 5, ty: 3.1, rot: 1.6,
            periodX: 10.6, periodY: 8.8, periodRot: 8.4,
            phaseX: 2.1, phaseY: 0.4, phaseRot: 2.9
        ),
        .init(
            color: NSColor(red: 0.667, green: 0.604, blue: 0.176, alpha: 1),
            points: [
                .init(x: 360, y: 60), .init(x: 398, y: 25), .init(x: 383, y: 237), .init(x: 456, y: 213),
                .init(x: 510, y: 195), .init(x: 543, y: 9), .init(x: 572, y: 64),
                .init(x: 605, y: 127), .init(x: 488, y: 249), .init(x: 428, y: 204)
            ],
            tx: 8, ty: 2.0, rot: 1.1,
            periodX: 8.2, periodY: 6.4, periodRot: 9.6,
            phaseX: 4.4, phaseY: 3.1, phaseRot: 0.7
        ),
        .init(
            color: NSColor(red: 0.608, green: 0.588, blue: 0.863, alpha: 1),
            points: [
                .init(x: 566, y: 148), .init(x: 589, y: 42), .init(x: 704, y: 52), .init(x: 746, y: 108),
                .init(x: 786, y: 165), .init(x: 729, y: 228), .init(x: 662, y: 195),
                .init(x: 587, y: 159), .init(x: 674, y: 15), .init(x: 744, y: 59),
                .init(x: 812, y: 103), .init(x: 754, y: 205), .init(x: 696, y: 211)
            ],
            tx: 6, ty: 3.4, rot: 1.4,
            periodX: 11.8, periodY: 9.8, periodRot: 7.8,
            phaseX: 1.2, phaseY: 5.0, phaseRot: 3.9
        ),
        .init(
            color: NSColor(red: 0.157, green: 0.153, blue: 0.125, alpha: 1),
            points: [
                .init(x: 705, y: 212), .init(x: 741, y: 154), .init(x: 805, y: 81), .init(x: 846, y: 62),
                .init(x: 892, y: 41), .init(x: 738, y: 254), .init(x: 708, y: 213)
            ],
            tx: 5, ty: 2.2, rot: 1.7,
            periodX: 9.8, periodY: 7.8, periodRot: 10.4,
            phaseX: 5.3, phaseY: 2.6, phaseRot: 1.5
        ),
        .init(
            color: NSColor(red: 0.835, green: 0.647, blue: 0.561, alpha: 1),
            points: [
                .init(x: 824, y: 182), .init(x: 849, y: 142), .init(x: 935, y: 71), .init(x: 951, y: 79),
                .init(x: 971, y: 89), .init(x: 879, y: 152), .init(x: 878, y: 181),
                .init(x: 877, y: 214), .init(x: 1_044, y: 213), .init(x: 1_076, y: 183),
                .init(x: 1_098, y: 162), .init(x: 949, y: 215), .init(x: 829, y: 182)
            ],
            tx: 7, ty: 2.9, rot: 1.2,
            periodX: 11.2, periodY: 9.4, periodRot: 8.9,
            phaseX: 3.7, phaseY: 4.2, phaseRot: 5.7
        ),
        .init(
            color: NSColor(red: 0.239, green: 0.388, blue: 0.933, alpha: 1),
            points: [
                .init(x: 1_021, y: 89), .init(x: 1_070, y: 64), .init(x: 1_245, y: 55), .init(x: 1_278, y: 66),
                .init(x: 1_312, y: 77), .init(x: 1_082, y: 96), .init(x: 1_071, y: 116),
                .init(x: 1_055, y: 143), .init(x: 1_277, y: 164), .init(x: 1_279, y: 203),
                .init(x: 1_281, y: 230), .init(x: 1_124, y: 213), .init(x: 1_032, y: 212)
            ],
            tx: 8, ty: 2.6, rot: 1.5,
            periodX: 8.8, periodY: 7.0, periodRot: 10.9,
            phaseX: 0.9, phaseY: 1.1, phaseRot: 2.3
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
