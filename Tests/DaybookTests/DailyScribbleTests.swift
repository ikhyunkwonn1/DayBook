import AppKit
import Foundation
import Testing
@testable import Daybook

struct DailyScribbleTests {
    @Test
    func rendersContactSheetWhenPreviewPathIsProvided() throws {
        guard let outputPath = ProcessInfo.processInfo.environment["DAYBOOK_SCRIBBLE_PREVIEW"] else {
            return
        }

        let service = DailyScribbleService()
        let rows = DailyScribbleService.words.enumerated().map { row, word -> String in
            let artwork = service.artwork(word: word, seedKey: "contact-sheet:\(word)")
            let paths = artwork.lines.map { line in
                "<path d=\"\(pathData(line.points))\" stroke=\"\(hex(line.color))\"/>"
            }.joined(separator: "\n")
            return "<g transform=\"translate(0 \(row * 280))\">\n\(paths)\n</g>"
        }.joined(separator: "\n")

        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="1400" height="1680" viewBox="0 0 1400 1680">
          <rect width="1400" height="1680" fill="#f7f7f3"/>
          <g fill="none" stroke-width="2.35" stroke-linecap="round" stroke-linejoin="round" opacity=".96">
            \(rows)
          </g>
        </svg>
        """
        try svg.write(toFile: outputPath, atomically: true, encoding: String.Encoding.utf8)
    }

    @Test
    func curatedCatalogHasTwoValidVariantsForEveryUsedLetter() {
        let requiredLetters = Set(DailyScribbleService.words.joined())
        let availableLetters = Set(HeroScribbleLibrary.all.map(\.letter))

        #expect(DailyScribbleService.words == ["moments", "whisper", "echoes", "musings", "traces", "moonlit"])
        #expect(requiredLetters == availableLetters)

        for letter in requiredLetters {
            let variants = HeroScribbleLibrary.variants(for: letter)
            #expect(variants.count == 2)
            #expect(Set(variants.map(\.weight)) == Set([.light, .heavy]))
        }

        for variant in HeroScribbleLibrary.all {
            #expect([7, 10, 13, 16].contains(variant.points.count))
            #expect((2...5).contains((variant.points.count - 1) / 3))
            #expect(variant.points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
            #expect(variant.maximumRotation > 0 && variant.maximumRotation <= 5)
        }
    }

    @Test
    func dailyWordSelectionIsStableAndNeverRepeatsOnAdjacentDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let service = DailyScribbleService()
        let firstDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        var words: [String] = []

        for offset in 0..<180 {
            let date = calendar.date(byAdding: .day, value: offset, to: firstDate)!
            let word = service.word(for: date, calendar: calendar)
            #expect(service.word(for: date, calendar: calendar) == word)
            words.append(word)
        }

        #expect(Set(words) == Set(DailyScribbleService.words))
        for index in 1..<words.count {
            #expect(words[index] != words[index - 1])
        }
    }

    @Test
    func assembledArtworkUsesTheApprovedPaletteInOrder() {
        let artwork = DailyScribbleService().artwork(word: "moments", seedKey: "palette-check")
        #expect(artwork.lines.map { hex($0.color) } == [
            "#eb7a54", "#4b9d63", "#aa9a2d", "#9b96dc", "#282720", "#d5a58f", "#3d63ee"
        ])
    }

    @Test
    func assembledArtworkIsDeterministicAndStaysInsideTheDesignSpace() {
        let service = DailyScribbleService()
        let variantsByID = Dictionary(uniqueKeysWithValues: HeroScribbleLibrary.all.map { ($0.id, $0) })

        for word in DailyScribbleService.words {
            for sample in 0..<24 {
                let key = "2040-02-\(String(format: "%02d", sample + 1)):\(word)"
                let first = service.artwork(word: word, seedKey: key)
                let second = service.artwork(word: word, seedKey: key)

                #expect(first.word == word)
                #expect(first.lines.count == word.count)
                #expect(first.designatedDecoyIndex >= 0 && first.designatedDecoyIndex < word.count)
                #expect(first.lines.map(\.sourceVariantID) == second.lines.map(\.sourceVariantID))
                #expect(first.lines.map(\.points) == second.lines.map(\.points))
                #expect(variantsByID[first.lines[first.designatedDecoyIndex].sourceVariantID]?.decoyTrait != nil)

                let weights = first.lines.compactMap { variantsByID[$0.sourceVariantID]?.weight }
                #expect(weights.count == first.lines.count)
                for index in 1..<weights.count {
                    #expect(weights[index] != weights[index - 1])
                }

                for line in first.lines {
                    #expect([7, 10, 13, 16].contains(line.points.count))
                    #expect(line.points.allSatisfy { point in
                        point.x >= 28 && point.x <= 1_372 && point.y >= 40 && point.y <= 250
                    })
                }
            }
        }
    }

    @Test
    func artworkDateUsesTheProvidedLocalCalendar() {
        let service = DailyScribbleService()
        let instant = Date(timeIntervalSince1970: 1_767_225_000) // 2025-12-31 23:50 UTC
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        let newYorkArt = service.artwork(for: instant, calendar: newYork)
        let tokyoArt = service.artwork(for: instant, calendar: tokyo)

        #expect(newYorkArt.id.hasPrefix("2025-12-31:"))
        #expect(tokyoArt.id.hasPrefix("2026-01-01:"))
    }

    private func pathData(_ points: [CGPoint]) -> String {
        guard let first = points.first else { return "" }
        var data = "M\(first.x),\(first.y)"
        for index in stride(from: 1, to: points.count - 2, by: 3) {
            data += " C\(points[index].x),\(points[index].y) \(points[index + 1].x),\(points[index + 1].y) \(points[index + 2].x),\(points[index + 2].y)"
        }
        return data
    }

    private func hex(_ color: NSColor) -> String {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        return String(
            format: "#%02x%02x%02x",
            Int((rgb.redComponent * 255).rounded()),
            Int((rgb.greenComponent * 255).rounded()),
            Int((rgb.blueComponent * 255).rounded())
        )
    }
}
