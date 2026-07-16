import AppKit
import Foundation

enum HeroGesturePrimitive: String, CaseIterable {
    case loop
    case arch
    case wave
    case cross
    case reverse
    case curl
    case light
}

enum HeroVisualWeight: String {
    case light
    case heavy
}

enum HeroDecoyTrait: String {
    case arch
    case hook
    case loop
    case numeral
    case ribbon
    case slash
}

struct HeroScribbleVariant {
    let id: String
    let letter: Character
    let primitive: HeroGesturePrimitive
    let weight: HeroVisualWeight
    let mirrorSafe: Bool
    let decoyTrait: HeroDecoyTrait?
    let maximumRotation: CGFloat
    let points: [CGPoint]
}

struct HeroMotionProfile {
    let tx: CGFloat
    let ty: CGFloat
    let rotation: CGFloat
    let periodX: Double
    let periodY: Double
    let periodRotation: Double
    let phaseX: Double
    let phaseY: Double
    let phaseRotation: Double
}

struct HeroLineSpec {
    let sourceVariantID: String
    let color: NSColor
    let points: [CGPoint]
    let tx: CGFloat
    let ty: CGFloat
    let rot: CGFloat
    let wx: Double
    let wy: Double
    let wr: Double
    let px: Double
    let py: Double
    let pr: Double

    init(
        sourceVariantID: String,
        color: NSColor,
        points: [CGPoint],
        motion: HeroMotionProfile
    ) {
        self.sourceVariantID = sourceVariantID
        self.color = color
        self.points = points
        self.tx = motion.tx
        self.ty = motion.ty
        self.rot = motion.rotation
        self.wx = 2 * .pi / motion.periodX
        self.wy = 2 * .pi / motion.periodY
        self.wr = 2 * .pi / motion.periodRotation
        self.px = motion.phaseX
        self.py = motion.phaseY
        self.pr = motion.phaseRotation
    }
}

struct DailyHeroArtwork {
    let id: String
    let word: String
    let designatedDecoyIndex: Int
    let lines: [HeroLineSpec]
}

struct DailyScribbleService {
    static let words = [
        "moments",
        "whisper",
        "echoes",
        "musings",
        "traces",
        "moonlit"
    ]

    func artwork(for date: Date, calendar: Calendar) -> DailyHeroArtwork {
        let dateKey = date.diaryKey(calendar: calendar)
        return artwork(word: word(for: date, calendar: calendar), seedKey: dateKey)
    }

    func word(for date: Date, calendar: Calendar) -> String {
        let startOfDay = calendar.startOfDay(for: date)
        let ordinal = calendar.ordinality(of: .day, in: .era, for: startOfDay)
            ?? Int(startOfDay.timeIntervalSinceReferenceDate / 86_400)
        let position = positiveRemainder(ordinal, divisor: Self.words.count)
        let block = floorDivision(ordinal, divisor: Self.words.count)
        return wordOrder(forBlock: block)[position]
    }

    func artwork(word: String, seedKey: String) -> DailyHeroArtwork {
        let letters = Array(word)
        precondition((5...8).contains(letters.count), "Hero words must contain 5...8 letters")

        let options = letters.map { letter -> [HeroScribbleVariant] in
            let variants = HeroScribbleLibrary.variants(for: letter)
            precondition(variants.count >= 2, "Missing two variants for hero letter: \(letter)")
            return Array(variants.prefix(2))
        }

        var selectionRandom = StableScribbleRandom(key: "\(seedKey):variants")
        let selected = selectVariants(options: options, using: &selectionRandom)
        let decoyCandidates = selected.indices.filter { selected[$0].decoyTrait != nil }
        let decoyIndex = decoyCandidates.isEmpty
            ? selectionRandom.nextInt(upperBound: selected.count)
            : decoyCandidates[selectionRandom.nextInt(upperBound: decoyCandidates.count)]

        var layoutRandom = StableScribbleRandom(key: "\(seedKey):layout")
        let verticalPhase = layoutRandom.nextBool()
        let lines = selected.enumerated().map { index, variant in
            let points = positionedPoints(
                for: variant,
                index: index,
                count: selected.count,
                verticalPhase: verticalPhase,
                random: &layoutRandom
            )
            return HeroLineSpec(
                sourceVariantID: variant.id,
                color: Self.palette[index % Self.palette.count],
                points: points,
                motion: Self.motionProfiles[index % Self.motionProfiles.count]
            )
        }

        return DailyHeroArtwork(
            id: "\(seedKey):\(word)",
            word: word,
            designatedDecoyIndex: decoyIndex,
            lines: lines
        )
    }

    private func selectVariants(
        options: [[HeroScribbleVariant]],
        using random: inout StableScribbleRandom
    ) -> [HeroScribbleVariant] {
        var bestScore = Int.min
        var bestMasks: [Int] = []

        for mask in 0..<(1 << options.count) {
            let variants = options.enumerated().map { index, variants in
                variants[(mask >> index) & 1]
            }

            var score = 0
            for index in 1..<variants.count {
                score += variants[index - 1].weight == variants[index].weight ? -18 : 42
            }

            let lightCount = variants.filter { $0.weight == .light }.count
            score -= abs(variants.count - lightCount * 2) * 3

            for left in variants.indices {
                for right in variants.indices where right > left {
                    if options[left][0].letter == options[right][0].letter,
                       variants[left].id == variants[right].id {
                        score -= 12
                    }
                }
            }

            if score > bestScore {
                bestScore = score
                bestMasks = [mask]
            } else if score == bestScore {
                bestMasks.append(mask)
            }
        }

        let chosenMask = bestMasks[random.nextInt(upperBound: bestMasks.count)]
        return options.enumerated().map { index, variants in
            variants[(chosenMask >> index) & 1]
        }
    }

    private func positionedPoints(
        for variant: HeroScribbleVariant,
        index: Int,
        count: Int,
        verticalPhase: Bool,
        random: inout StableScribbleRandom
    ) -> [CGPoint] {
        let sourceBounds = bounds(of: variant.points)
        let sourceCenter = CGPoint(x: sourceBounds.midX, y: sourceBounds.midY)
        let mirror: CGFloat = variant.mirrorSafe && random.nextBool() ? -1 : 1
        let lengthScale = min(1.12, max(0.88, pow(7 / CGFloat(count), 0.62)))
        let scale = lengthScale * random.nextCGFloat(in: 0.90...1.10)
        let radians = random.nextCGFloat(in: -variant.maximumRotation...variant.maximumRotation) * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)

        var transformed = variant.points.map { point -> CGPoint in
            let x = (point.x - sourceCenter.x) * mirror * scale
            let y = (point.y - sourceCenter.y) * scale
            return CGPoint(
                x: x * cosine - y * sine,
                y: x * sine + y * cosine
            )
        }

        let initialBounds = bounds(of: transformed)
        if initialBounds.height > 204 {
            let correction = 204 / initialBounds.height
            transformed = transformed.map { CGPoint(x: $0.x * correction, y: $0.y * correction) }
        }

        let outerMargin: CGFloat = 54
        let usableWidth: CGFloat = 1_400 - outerMargin * 2
        let zoneWidth = usableWidth / CGFloat(count)
        let centerX = outerMargin + zoneWidth * (CGFloat(index) + 0.5)
            + random.nextCGFloat(in: -zoneWidth * 0.07...zoneWidth * 0.07)
        let rises = (index.isMultiple(of: 2) == verticalPhase)
        let centerY: CGFloat = 140 + (rises ? -12 : 12) + random.nextCGFloat(in: -7...7)

        let localBounds = bounds(of: transformed)
        var positioned = transformed.map {
            CGPoint(x: $0.x + centerX - localBounds.midX, y: $0.y + centerY - localBounds.midY)
        }

        let safeX: ClosedRange<CGFloat> = 28...1_372
        let safeY: ClosedRange<CGFloat> = 40...250
        let finalBounds = bounds(of: positioned)
        var adjustment = CGPoint.zero
        if finalBounds.minX < safeX.lowerBound { adjustment.x += safeX.lowerBound - finalBounds.minX }
        if finalBounds.maxX > safeX.upperBound { adjustment.x -= finalBounds.maxX - safeX.upperBound }
        if finalBounds.minY < safeY.lowerBound { adjustment.y += safeY.lowerBound - finalBounds.minY }
        if finalBounds.maxY > safeY.upperBound { adjustment.y -= finalBounds.maxY - safeY.upperBound }

        if adjustment != .zero {
            positioned = positioned.map { CGPoint(x: $0.x + adjustment.x, y: $0.y + adjustment.y) }
        }
        return positioned
    }

    private func wordOrder(forBlock block: Int) -> [String] {
        var order = rawWordOrder(forBlock: block)
        guard let previousLast = rawWordOrder(forBlock: block - 1).last,
              order.first == previousLast,
              order.count > 1 else {
            return order
        }
        order.swapAt(0, 1)
        return order
    }

    private func rawWordOrder(forBlock block: Int) -> [String] {
        var order = Self.words
        var random = StableScribbleRandom(key: "daybook.hero.word-block:\(block)")
        guard order.count > 1 else { return order }
        for index in stride(from: order.count - 1, through: 1, by: -1) {
            order.swapAt(index, random.nextInt(upperBound: index + 1))
        }
        return order
    }

    private func positiveRemainder(_ value: Int, divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }

    private func floorDivision(_ value: Int, divisor: Int) -> Int {
        let quotient = value / divisor
        let remainder = value % divisor
        return remainder < 0 ? quotient - 1 : quotient
    }

    private func bounds(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .null }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static let palette: [NSColor] = [
        NSColor(red: 0.922, green: 0.478, blue: 0.329, alpha: 1),
        NSColor(red: 0.294, green: 0.616, blue: 0.388, alpha: 1),
        NSColor(red: 0.667, green: 0.604, blue: 0.176, alpha: 1),
        NSColor(red: 0.608, green: 0.588, blue: 0.863, alpha: 1),
        NSColor(red: 0.157, green: 0.153, blue: 0.125, alpha: 1),
        NSColor(red: 0.835, green: 0.647, blue: 0.561, alpha: 1),
        NSColor(red: 0.239, green: 0.388, blue: 0.933, alpha: 1)
    ]

    private static let motionProfiles: [HeroMotionProfile] = [
        .init(tx: 7, ty: 2.4, rotation: 1.3, periodX: 9.2, periodY: 7.4, periodRotation: 11.0, phaseX: 0.3, phaseY: 1.7, phaseRotation: 4.8),
        .init(tx: 5, ty: 3.1, rotation: 1.6, periodX: 10.6, periodY: 8.8, periodRotation: 8.4, phaseX: 2.1, phaseY: 0.4, phaseRotation: 2.9),
        .init(tx: 8, ty: 2.0, rotation: 1.1, periodX: 8.2, periodY: 6.4, periodRotation: 9.6, phaseX: 4.4, phaseY: 3.1, phaseRotation: 0.7),
        .init(tx: 6, ty: 3.4, rotation: 1.4, periodX: 11.8, periodY: 9.8, periodRotation: 7.8, phaseX: 1.2, phaseY: 5.0, phaseRotation: 3.9),
        .init(tx: 5, ty: 2.2, rotation: 1.7, periodX: 9.8, periodY: 7.8, periodRotation: 10.4, phaseX: 5.3, phaseY: 2.6, phaseRotation: 1.5),
        .init(tx: 7, ty: 2.9, rotation: 1.2, periodX: 11.2, periodY: 9.4, periodRotation: 8.9, phaseX: 3.7, phaseY: 4.2, phaseRotation: 5.7),
        .init(tx: 8, ty: 2.6, rotation: 1.5, periodX: 8.8, periodY: 7.0, periodRotation: 10.9, phaseX: 0.9, phaseY: 1.1, phaseRotation: 2.3),
        .init(tx: 6, ty: 2.7, rotation: 1.35, periodX: 10.1, periodY: 8.1, periodRotation: 9.3, phaseX: 2.8, phaseY: 4.6, phaseRotation: 0.5)
    ]
}

struct StableScribbleRandom {
    private var state: UInt64

    init(key: String) {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        state = hash
    }

    mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(nextUInt64() % UInt64(upperBound))
    }

    mutating func nextBool() -> Bool {
        nextUInt64() & 1 == 0
    }

    mutating func nextCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        let unit = CGFloat(Double(nextUInt64() >> 11) / Double(1 << 53))
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }
}
