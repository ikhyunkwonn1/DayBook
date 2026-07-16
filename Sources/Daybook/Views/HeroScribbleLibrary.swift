import Foundation

enum HeroScribbleLibrary {
    static func variants(for letter: Character) -> [HeroScribbleVariant] {
        variantsByLetter[letter] ?? []
    }

    static let all: [HeroScribbleVariant] = [
        // MARK: m — uneven repetition, never a countable zigzag
        variant("m-a", "m", .wave, .heavy, false, .numeral, 3.2, [
            .init(x: 0, y: 110),
            .init(x: 18, y: 24), .init(x: 150, y: 10), .init(x: 188, y: 56),
            .init(x: 218, y: 100), .init(x: 58, y: 128), .init(x: 36, y: 164),
            .init(x: 62, y: 192), .init(x: 78, y: 156), .init(x: 102, y: 174),
            .init(x: 126, y: 192), .init(x: 142, y: 156), .init(x: 166, y: 174),
            .init(x: 190, y: 192), .init(x: 212, y: 158), .init(x: 232, y: 138)
        ]),
        variant("m-b", "m", .wave, .light, true, nil, 3.0, [
            .init(x: 8, y: 156),
            .init(x: 28, y: 44), .init(x: 60, y: 12), .init(x: 88, y: 80),
            .init(x: 112, y: 142), .init(x: 134, y: 158), .init(x: 152, y: 108),
            .init(x: 168, y: 64), .init(x: 196, y: 72), .init(x: 208, y: 118),
            .init(x: 214, y: 156), .init(x: 182, y: 162), .init(x: 176, y: 124)
        ]),

        // MARK: o — an enclosure with a conspicuous gap and off-axis exit
        variant("o-a", "o", .loop, .heavy, false, .numeral, 3.5, [
            .init(x: 8, y: 80),
            .init(x: 48, y: 18), .init(x: 148, y: 14), .init(x: 188, y: 76),
            .init(x: 214, y: 138), .init(x: 110, y: 196), .init(x: 44, y: 156),
            .init(x: 16, y: 136), .init(x: 20, y: 112), .init(x: 42, y: 98)
        ]),

        // MARK: e — a tucked curl crossing under its own return
        variant("e-a", "e", .curl, .heavy, false, .loop, 3.2, [
            .init(x: 8, y: 130),
            .init(x: 28, y: 38), .init(x: 118, y: 22), .init(x: 144, y: 84),
            .init(x: 160, y: 138), .init(x: 76, y: 156), .init(x: 58, y: 102),
            .init(x: 70, y: 44), .init(x: 156, y: 24), .init(x: 192, y: 76),
            .init(x: 218, y: 128), .init(x: 154, y: 170), .init(x: 118, y: 138)
        ]),

        // MARK: n — one breaking rise and fold-back
        variant("n-a", "n", .arch, .light, true, nil, 3.7, [
            .init(x: 6, y: 166),
            .init(x: 34, y: 88), .init(x: 82, y: 44), .init(x: 128, y: 36),
            .init(x: 172, y: 30), .init(x: 140, y: 110), .init(x: 104, y: 158)
        ]),

        // MARK: t — a lazy sweep with one quiet self-intersection
        variant("t-a", "t", .cross, .heavy, false, .slash, 3.0, [
            .init(x: 6, y: 128),
            .init(x: 66, y: 98), .init(x: 174, y: 86), .init(x: 234, y: 108),
            .init(x: 266, y: 120), .init(x: 258, y: 70), .init(x: 214, y: 60),
            .init(x: 158, y: 48), .init(x: 108, y: 82), .init(x: 100, y: 146),
            .init(x: 98, y: 188), .init(x: 130, y: 192), .init(x: 146, y: 162)
        ]),

        // MARK: s — an asymmetric ribbon with two soft reversals
        variant("s-a", "s", .reverse, .heavy, true, .ribbon, 3.4, [
            .init(x: 4, y: 50),
            .init(x: 68, y: 18), .init(x: 166, y: 22), .init(x: 218, y: 54),
            .init(x: 256, y: 82), .init(x: 224, y: 118), .init(x: 164, y: 122),
            .init(x: 104, y: 126), .init(x: 36, y: 138), .init(x: 20, y: 172),
            .init(x: 52, y: 206), .init(x: 136, y: 200), .init(x: 200, y: 174)
        ]),

        // MARK: i — a light vertical tendency interrupted by unrelated curls
        variant("i-a", "i", .light, .light, true, .ribbon, 4.0, [
            .init(x: 28, y: 162),
            .init(x: 56, y: 178), .init(x: 102, y: 164), .init(x: 92, y: 128),
            .init(x: 82, y: 92), .init(x: 98, y: 42), .init(x: 126, y: 48),
            .init(x: 150, y: 54), .init(x: 150, y: 76), .init(x: 132, y: 78)
        ]),
        variant("i-b", "i", .light, .heavy, true, .hook, 4.0, [
            .init(x: 28, y: 92),
            .init(x: 58, y: 72), .init(x: 116, y: 78), .init(x: 108, y: 112),
            .init(x: 100, y: 144), .init(x: 68, y: 192), .init(x: 104, y: 198),
            .init(x: 132, y: 204), .init(x: 168, y: 178), .init(x: 148, y: 160)
        ]),

        // MARK: l — a long drift with a terminal tuck, not a stem
        variant("l-a", "l", .light, .light, true, nil, 3.5, [
            .init(x: 42, y: 176),
            .init(x: 58, y: 140), .init(x: 76, y: 54), .init(x: 110, y: 42),
            .init(x: 146, y: 30), .init(x: 132, y: 86), .init(x: 112, y: 124),
            .init(x: 94, y: 160), .init(x: 102, y: 194), .init(x: 138, y: 190),
            .init(x: 164, y: 186), .init(x: 174, y: 166), .init(x: 154, y: 158)
        ]),
        variant("l-b", "l", .light, .heavy, true, .hook, 4.0, [
            .init(x: 32, y: 68),
            .init(x: 68, y: 42), .init(x: 132, y: 48), .init(x: 126, y: 82),
            .init(x: 118, y: 112), .init(x: 78, y: 160), .init(x: 100, y: 184),
            .init(x: 126, y: 212), .init(x: 166, y: 192), .init(x: 158, y: 164)
        ]),

        // MARK: p — an offset enclosure that never resolves into a bowl and stem
        variant("p-a", "p", .loop, .heavy, true, .hook, 4.5, [
            .init(x: 22, y: 154),
            .init(x: 54, y: 74), .init(x: 134, y: 42), .init(x: 176, y: 76),
            .init(x: 212, y: 108), .init(x: 164, y: 166), .init(x: 104, y: 162),
            .init(x: 52, y: 158), .init(x: 52, y: 112), .init(x: 88, y: 98),
            .init(x: 122, y: 82), .init(x: 148, y: 104), .init(x: 132, y: 124)
        ]),
        variant("p-b", "p", .loop, .light, true, nil, 4.0, [
            .init(x: 20, y: 166),
            .init(x: 44, y: 132), .init(x: 70, y: 54), .init(x: 132, y: 48),
            .init(x: 188, y: 42), .init(x: 216, y: 92), .init(x: 190, y: 128),
            .init(x: 164, y: 164), .init(x: 102, y: 178), .init(x: 70, y: 146),
            .init(x: 44, y: 116), .init(x: 94, y: 88), .init(x: 132, y: 108),
            .init(x: 150, y: 118), .init(x: 152, y: 140), .init(x: 132, y: 144)
        ]),

        // MARK: r — one rise and fall, with an unrelated ending turn
        variant("r-a", "r", .arch, .heavy, true, .hook, 4.0, [
            .init(x: 24, y: 164),
            .init(x: 50, y: 152), .init(x: 68, y: 80), .init(x: 110, y: 70),
            .init(x: 156, y: 58), .init(x: 196, y: 96), .init(x: 178, y: 130),
            .init(x: 160, y: 164), .init(x: 112, y: 178), .init(x: 128, y: 194),
            .init(x: 146, y: 210), .init(x: 184, y: 194), .init(x: 174, y: 176)
        ]),
        variant("r-b", "r", .arch, .light, false, .loop, 3.5, [
            .init(x: 24, y: 88),
            .init(x: 58, y: 112), .init(x: 86, y: 178), .init(x: 128, y: 176),
            .init(x: 170, y: 174), .init(x: 210, y: 110), .init(x: 184, y: 80),
            .init(x: 160, y: 54), .init(x: 118, y: 68), .init(x: 126, y: 100),
            .init(x: 132, y: 120), .init(x: 146, y: 132), .init(x: 162, y: 126)
        ]),

        // MARK: a — an open, tilted enclosure with an unrelated return
        variant("a-a", "a", .loop, .heavy, true, .hook, 3.5, [
            .init(x: 4, y: 96),
            .init(x: 26, y: 90), .init(x: 44, y: 118), .init(x: 70, y: 110),
            .init(x: 104, y: 52), .init(x: 154, y: 38), .init(x: 180, y: 70),
            .init(x: 222, y: 108), .init(x: 168, y: 186), .init(x: 84, y: 176),
            .init(x: 58, y: 174), .init(x: 42, y: 192), .init(x: 24, y: 188),
            .init(x: 4, y: 178), .init(x: 0, y: 150), .init(x: 16, y: 132)
        ]),
        variant("a-b", "a", .loop, .light, true, .arch, 4.0, [
            .init(x: 12, y: 176),
            .init(x: 34, y: 190), .init(x: 52, y: 142), .init(x: 72, y: 154),
            .init(x: 96, y: 88), .init(x: 128, y: 38), .init(x: 174, y: 58),
            .init(x: 226, y: 78), .init(x: 206, y: 156), .init(x: 148, y: 176),
            .init(x: 118, y: 190), .init(x: 92, y: 172), .init(x: 82, y: 154),
            .init(x: 68, y: 132), .init(x: 90, y: 112), .init(x: 120, y: 126)
        ]),

        // MARK: c — a curl that overshoots and tucks instead of describing a letter
        variant("c-a", "c", .curl, .heavy, true, .numeral, 3.0, [
            .init(x: 8, y: 66),
            .init(x: 68, y: 24), .init(x: 160, y: 30), .init(x: 188, y: 82),
            .init(x: 232, y: 116), .init(x: 144, y: 196), .init(x: 62, y: 164),
            .init(x: 32, y: 146), .init(x: 78, y: 96), .init(x: 132, y: 116),
            .init(x: 160, y: 132), .init(x: 164, y: 170), .init(x: 124, y: 176)
        ]),
        variant("c-b", "c", .curl, .light, true, .arch, 4.0, [
            .init(x: 10, y: 170),
            .init(x: 22, y: 154), .init(x: 42, y: 126), .init(x: 58, y: 112),
            .init(x: 92, y: 52), .init(x: 136, y: 34), .init(x: 174, y: 58),
            .init(x: 218, y: 82), .init(x: 214, y: 130), .init(x: 186, y: 150),
            .init(x: 152, y: 176), .init(x: 112, y: 174), .init(x: 96, y: 148),
            .init(x: 84, y: 126), .init(x: 114, y: 104), .init(x: 136, y: 116)
        ]),

        // MARK: g — an open orbit with an off-axis terminal dive
        variant("g-a", "g", .loop, .light, false, .slash, 3.0, [
            .init(x: 6, y: 120),
            .init(x: 24, y: 112), .init(x: 46, y: 106), .init(x: 66, y: 100),
            .init(x: 88, y: 52), .init(x: 142, y: 34), .init(x: 178, y: 58),
            .init(x: 218, y: 90), .init(x: 206, y: 142), .init(x: 158, y: 154),
            .init(x: 132, y: 164), .init(x: 110, y: 154), .init(x: 92, y: 146),
            .init(x: 126, y: 160), .init(x: 148, y: 214), .init(x: 160, y: 198)
        ]),
        variant("g-b", "g", .loop, .heavy, false, .hook, 3.5, [
            .init(x: 20, y: 76),
            .init(x: 32, y: 82), .init(x: 46, y: 112), .init(x: 66, y: 106),
            .init(x: 88, y: 50), .init(x: 132, y: 34), .init(x: 160, y: 54),
            .init(x: 214, y: 76), .init(x: 216, y: 122), .init(x: 190, y: 142),
            .init(x: 162, y: 168), .init(x: 126, y: 170), .init(x: 102, y: 150),
            .init(x: 82, y: 134), .init(x: 112, y: 190), .init(x: 76, y: 202)
        ]),

        // MARK: h — a breaking rise-and-fall with asymmetric tails
        variant("h-a", "h", .arch, .light, true, nil, 4.0, [
            .init(x: 8, y: 172),
            .init(x: 24, y: 174), .init(x: 38, y: 150), .init(x: 54, y: 142),
            .init(x: 78, y: 90), .init(x: 100, y: 42), .init(x: 142, y: 54),
            .init(x: 190, y: 62), .init(x: 222, y: 124), .init(x: 196, y: 156),
            .init(x: 180, y: 172), .init(x: 206, y: 186), .init(x: 224, y: 178)
        ]),
        variant("h-b", "h", .arch, .heavy, true, .ribbon, 3.5, [
            .init(x: 8, y: 80),
            .init(x: 22, y: 76), .init(x: 32, y: 108), .init(x: 50, y: 104),
            .init(x: 76, y: 78), .init(x: 102, y: 32), .init(x: 140, y: 44),
            .init(x: 188, y: 50), .init(x: 224, y: 122), .init(x: 198, y: 154),
            .init(x: 176, y: 178), .init(x: 110, y: 176), .init(x: 82, y: 146)
        ]),

        // MARK: u — an inverted arch melted into a looping basin
        variant("u-a", "u", .arch, .heavy, true, .numeral, 4.0, [
            .init(x: 8, y: 102),
            .init(x: 34, y: 46), .init(x: 102, y: 38), .init(x: 94, y: 92),
            .init(x: 86, y: 148), .init(x: 102, y: 196), .init(x: 156, y: 178),
            .init(x: 206, y: 160), .init(x: 168, y: 70), .init(x: 210, y: 60),
            .init(x: 238, y: 54), .init(x: 230, y: 132), .init(x: 172, y: 118),
            .init(x: 140, y: 110), .init(x: 112, y: 134), .init(x: 128, y: 154)
        ]),
        variant("u-b", "u", .arch, .light, true, .ribbon, 5.0, [
            .init(x: 16, y: 176),
            .init(x: 48, y: 194), .init(x: 70, y: 156), .init(x: 52, y: 118),
            .init(x: 32, y: 72), .init(x: 90, y: 48), .init(x: 120, y: 92),
            .init(x: 150, y: 140), .init(x: 176, y: 174), .init(x: 204, y: 128),
            .init(x: 228, y: 92), .init(x: 206, y: 52), .init(x: 174, y: 70)
        ]),

        // MARK: w — uneven, soft repetition with no countable teeth
        variant("w-a", "w", .wave, .heavy, true, .loop, 3.5, [
            .init(x: 12, y: 142),
            .init(x: 24, y: 66), .init(x: 94, y: 38), .init(x: 102, y: 94),
            .init(x: 110, y: 142), .init(x: 58, y: 178), .init(x: 72, y: 120),
            .init(x: 84, y: 66), .init(x: 140, y: 72), .init(x: 138, y: 126),
            .init(x: 136, y: 176), .init(x: 196, y: 186), .init(x: 204, y: 116),
            .init(x: 210, y: 72), .init(x: 174, y: 58), .init(x: 162, y: 88)
        ]),
        variant("w-b", "w", .wave, .light, true, nil, 4.5, [
            .init(x: 14, y: 182),
            .init(x: 42, y: 156), .init(x: 20, y: 96), .init(x: 56, y: 82),
            .init(x: 92, y: 58), .init(x: 88, y: 146), .init(x: 126, y: 154),
            .init(x: 164, y: 162), .init(x: 154, y: 72), .init(x: 206, y: 56),
            .init(x: 232, y: 48), .init(x: 228, y: 104), .init(x: 198, y: 120)
        ]),

        // Contrasting variants for letters already established by "moments".
        variant("o-b", "o", .loop, .light, true, .numeral, 4.0, [
            .init(x: 16, y: 150),
            .init(x: 34, y: 102), .init(x: 70, y: 42), .init(x: 126, y: 44),
            .init(x: 188, y: 44), .init(x: 218, y: 110), .init(x: 182, y: 156),
            .init(x: 148, y: 194), .init(x: 84, y: 178), .init(x: 104, y: 130)
        ]),
        variant("e-b", "e", .curl, .light, true, .numeral, 5.0, [
            .init(x: 10, y: 158),
            .init(x: 42, y: 132), .init(x: 42, y: 54), .init(x: 112, y: 48),
            .init(x: 176, y: 40), .init(x: 200, y: 92), .init(x: 158, y: 118),
            .init(x: 112, y: 146), .init(x: 144, y: 186), .init(x: 218, y: 168)
        ]),
        variant("n-b", "n", .arch, .heavy, true, nil, 3.5, [
            .init(x: 12, y: 172),
            .init(x: 42, y: 150), .init(x: 26, y: 88), .init(x: 72, y: 124),
            .init(x: 96, y: 76), .init(x: 126, y: 38), .init(x: 150, y: 76),
            .init(x: 176, y: 110), .init(x: 170, y: 168), .init(x: 190, y: 164),
            .init(x: 212, y: 160), .init(x: 236, y: 142), .init(x: 226, y: 110)
        ]),
        variant("t-b", "t", .cross, .light, true, .loop, 3.0, [
            .init(x: 14, y: 80),
            .init(x: 60, y: 52), .init(x: 164, y: 48), .init(x: 210, y: 86),
            .init(x: 224, y: 110), .init(x: 144, y: 122), .init(x: 80, y: 166),
            .init(x: 36, y: 196), .init(x: 90, y: 48), .init(x: 176, y: 146)
        ]),
        variant("s-b", "s", .reverse, .light, true, .numeral, 5.0, [
            .init(x: 12, y: 118),
            .init(x: 38, y: 58), .init(x: 126, y: 44), .init(x: 178, y: 70),
            .init(x: 226, y: 94), .init(x: 194, y: 126), .init(x: 128, y: 132),
            .init(x: 62, y: 138), .init(x: 34, y: 160), .init(x: 90, y: 186)
        ])
    ]

    private static let variantsByLetter = Dictionary(grouping: all, by: \.letter)

    private static func variant(
        _ id: String,
        _ letter: Character,
        _ primitive: HeroGesturePrimitive,
        _ weight: HeroVisualWeight,
        _ mirrorSafe: Bool,
        _ decoyTrait: HeroDecoyTrait?,
        _ maximumRotation: CGFloat,
        _ points: [CGPoint]
    ) -> HeroScribbleVariant {
        HeroScribbleVariant(
            id: id,
            letter: letter,
            primitive: primitive,
            weight: weight,
            mirrorSafe: mirrorSafe,
            decoyTrait: decoyTrait,
            maximumRotation: maximumRotation,
            points: points
        )
    }
}
