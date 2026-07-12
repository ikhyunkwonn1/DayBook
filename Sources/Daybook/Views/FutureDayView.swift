import SwiftUI

struct FutureDayView: View {
    @ObservedObject var viewModel: DaybookViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Not yet written", detail: "the day ahead")

            UnsettledInkArt(seed: viewModel.selectedDate.diaryKey(calendar: viewModel.calendar).inkSeed())
                .frame(minHeight: 420, maxHeight: .infinity)
                .padding(.top, 26)

            Text(viewModel.dailyHeading)
                .font(.system(size: 20, weight: .regular, design: .serif))
                .foregroundStyle(EditorialPalette.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(alignment: .bottom) {
                    EditorialRule()
                }

            Text("Come back once the day has been lived")
                .font(.system(size: 10, weight: .regular, design: .default))
                .foregroundStyle(EditorialPalette.muted)
                .textCase(.uppercase)
                .tracking(0.9)
                .padding(.top, 16)
        }
    }
}

/// Ruled writing lines that lose their certainty as they descend: the ruling wavers, breaks
/// apart, and settles into scattered ink. Every date frays differently, and always the same way.
private struct UnsettledInkArt: View {
    let seed: UInt64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let lineCount = 11
    private let step: CGFloat = 7

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            Canvas { canvas, size in
                let drift = context.date.timeIntervalSinceReferenceDate
                draw(in: &canvas, size: size, drift: drift)
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, drift: TimeInterval) {
        guard size.width > 0, size.height > 0 else { return }

        let spacing = size.height / CGFloat(lineCount)

        for line in 0..<lineCount {
            // 0 at the top (a clean rule) through 1 at the bottom (loose ink).
            let progress = Double(line) / Double(lineCount - 1)
            let chaos = pow(progress, 1.7)
            let baseline = spacing * (CGFloat(line) + 0.5)

            let amplitude = chaos * 13
            let frequency = 0.012 + rand(line, 0) * 0.01
            let phase = rand(line, 1) * .pi * 2
            let sway = drift * 0.22 * chaos

            let shade = shade(for: chaos)
            let width = 1 + chaos * 0.7

            var run: [CGPoint] = []
            var x: CGFloat = 0

            while x <= size.width {
                let segment = Int(x / step)
                let wobble = sin(Double(x) * frequency + phase + sway) * amplitude
                let jitter = (rand(line, segment + 2) - 0.5) * chaos * 9
                let y = baseline + CGFloat(wobble + jitter)

                run.append(CGPoint(x: x, y: y))

                // The higher the chaos, the more often the line simply stops.
                if rand(line, segment + 500) < chaos * 0.42 {
                    flush(run, in: &canvas, shade: shade, width: width, chaos: chaos)
                    run = []
                }

                x += step
            }

            flush(run, in: &canvas, shade: shade, width: width, chaos: chaos)
        }
    }

    /// Strokes a run of points, or leaves a single mark where the line has come apart entirely.
    private func flush(
        _ run: [CGPoint],
        in canvas: inout GraphicsContext,
        shade: Color,
        width: CGFloat,
        chaos: Double
    ) {
        guard let first = run.first else { return }

        if run.count == 1 {
            let radius = 0.9 + chaos * 0.8
            let dot = Path(ellipseIn: CGRect(
                x: first.x - radius,
                y: first.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            canvas.fill(dot, with: .color(shade))
            return
        }

        var path = Path()
        path.move(to: first)
        for point in run.dropFirst() {
            path.addLine(to: point)
        }
        canvas.stroke(path, with: .color(shade), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    /// Pale paper ruling at the top, settling into real ink where the page comes apart.
    private func shade(for chaos: Double) -> Color {
        let rule = (r: 0.865, g: 0.865, b: 0.835)
        let ink = (r: 0.43, g: 0.426, b: 0.39)
        return Color(
            red: rule.r + (ink.r - rule.r) * chaos,
            green: rule.g + (ink.g - rule.g) * chaos,
            blue: rule.b + (ink.b - rule.b) * chaos
        )
    }

    private func rand(_ line: Int, _ offset: Int) -> Double {
        var hash = seed
        for value in [UInt64(bitPattern: Int64(line)), UInt64(bitPattern: Int64(offset))] {
            hash ^= value &+ 0x9E37_79B9_7F4A_7C15
            hash &*= 1_099_511_628_211
            hash ^= hash >> 29
        }
        return Double(hash % 10_000) / 10_000
    }
}

private extension String {
    /// Same FNV-style walk `DailyHeadingService` uses, so a date's art is as stable as its heading.
    func inkSeed() -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}
