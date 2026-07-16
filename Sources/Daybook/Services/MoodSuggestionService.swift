import Foundation
import NaturalLanguage

protocol MoodSuggestionService {
    func suggest(for text: String) -> [MoodSuggestion]
}

/// Valence–arousal mood suggestion engine.
///
/// How it works:
/// 1. Valence (-1 negative … +1 positive) comes from NLTagger's on-device
///    sentiment score, computed over Latin-script words only.
/// 2. Arousal (-1 dull … +1 excited) is approximated from structural features
///    of the full text (exclamations weighted heaviest, caps, elongated words,
///    sentence length, fragments, ellipses, questions, interjections, emoji,
///    and sentiment magnitude).
/// 3. The entry becomes a point on the plane; the mood with the nearest home
///    coordinate wins. Exactly one suggestion is returned.
/// 4. Random pick is the last resort, used only when the text is too short
///    (< 5 words) for either axis to mean anything.
struct MoodGridSuggestionEngine: MoodSuggestionService {

    /// A mood anchored to a home coordinate on the valence–arousal plane.
    struct AnchoredMood {
        let card: MoodCard
        let valence: Double
        let arousal: Double
    }

    /// The finalized 3×3 grid. Rows: high / mid / low energy. Columns: negative / neutral / positive.
    static let grid: [AnchoredMood] = [
        AnchoredMood(card: MoodCard(label: "Restless", colorHex: "#546A7B", icon: "wind"), valence: -1.0, arousal: 0.65),
        AnchoredMood(card: MoodCard(label: "Intense", colorHex: "#4F8A8B", icon: "tornado"), valence: -0.75, arousal: 0.65),
        AnchoredMood(card: MoodCard(label: "Bright", colorHex: "#D68653", icon: "sun.max.fill"), valence: 0.65, arousal: 0.65),
        AnchoredMood(card: MoodCard(label: "Stormy", colorHex: "#8E5A5A", icon: "cloud.bolt.rain.fill"), valence: -1.0, arousal: 0.0),
        AnchoredMood(card: MoodCard(label: "Focused", colorHex: "#567C8D", icon: "pencil.line"), valence: -0.75, arousal: 0.0),
        AnchoredMood(card: MoodCard(label: "Grateful", colorHex: "#B9924B", icon: "hands.sparkles.fill"), valence: 0.65, arousal: 0.0),
        AnchoredMood(card: MoodCard(label: "Weary", colorHex: "#6E6A63", icon: "zzz"), valence: -1.0, arousal: -0.65),
        AnchoredMood(card: MoodCard(label: "Dreamy", colorHex: "#7E6B8F", icon: "moon.stars.fill"), valence: -0.75, arousal: -0.65),
        AnchoredMood(card: MoodCard(label: "Calm", colorHex: "#8A9A7B", icon: "leaf.fill"), valence: 0.65, arousal: -0.65)
    ]

    struct Analysis {
        let valence: Double
        let arousal: Double
        let suggestion: MoodSuggestion
    }

    private static let minimumWordCount = 5

    func suggest(for text: String) -> [MoodSuggestion] {
        [analyze(text).suggestion]
    }

    func analyze(_ text: String) -> Analysis {
        let words = text.split { $0.isWhitespace }.map(String.init)
        guard words.count >= Self.minimumWordCount else {
            let card = Self.grid.randomElement()!.card
            let suggestion = MoodSuggestion(card: card, reason: "Not enough text to read yet — a first guess.")
            return Analysis(valence: 0, arousal: 0, suggestion: suggestion)
        }

        let valence = Self.valence(of: text)
        let arousal = Self.arousal(of: text, words: words, valence: valence)

        let nearest = Self.grid.min { lhs, rhs in
            Self.distanceSquared(lhs, valence: valence, arousal: arousal)
                < Self.distanceSquared(rhs, valence: valence, arousal: arousal)
        }!
        let suggestion = MoodSuggestion(card: nearest.card, reason: Self.reasonText(valence: valence, arousal: arousal))
        return Analysis(valence: valence, arousal: arousal, suggestion: suggestion)
    }

    // MARK: - Valence

    private static func valence(of text: String) -> Double {
        let english = latinOnlyText(from: text)
        guard !english.isEmpty else { return 0 }

        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = english
        var total = 0.0
        var count = 0
        tagger.enumerateTags(in: english.startIndex..<english.endIndex, unit: .paragraph, scheme: .sentimentScore, options: []) { tag, _ in
            if let score = tag.flatMap({ Double($0.rawValue) }) {
                total += score
                count += 1
            }
            return true
        }
        return count > 0 ? total / Double(count) : 0
    }

    /// Drops words containing non-Latin letters so unsupported languages don't
    /// skew the English sentiment model. Punctuation, digits, and emoji pass through.
    private static func latinOnlyText(from text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                line.split(separator: " ")
                    .filter { word in
                        word.unicodeScalars.allSatisfy { scalar in
                            !scalar.properties.isAlphabetic || scalar.value < 0x0250
                        }
                    }
                    .joined(separator: " ")
            }
            .joined(separator: "\n")
    }

    // MARK: - Arousal

    private static func arousal(of text: String, words: [String], valence: Double) -> Double {
        let sentences = sentenceStrings(in: text)
        let sentenceCount = Double(max(sentences.count, 1))
        let wordCount = Double(words.count)

        // Exclamations, the heaviest signal. Runs escalate: "!" 1, "!!" 2.5, "!!!"+ 4.
        var exclamationWeight = 0.0
        var runLength = 0
        func flushRun() {
            guard runLength > 0 else { return }
            switch runLength {
            case 1: exclamationWeight += 1.0
            case 2: exclamationWeight += 2.5
            default: exclamationWeight += 4.0
            }
            runLength = 0
        }
        for character in text {
            if character == "!" { runLength += 1 } else { flushRun() }
        }
        flushRun()
        let exclamationScore = min(exclamationWeight / sentenceCount, 1.0)

        // ALL-CAPS words of 2+ letters ("I" and single letters don't count).
        let capsCount = words.filter { word in
            let letters = word.filter(\.isLetter)
            return letters.count >= 2 && letters.allSatisfy(\.isUppercase)
        }.count
        let capsScore = min(Double(capsCount) / wordCount * 20, 1.0)

        // Elongated words ("soooo", "ughhh"): 3+ of the same letter in a row.
        let elongatedCount = words.filter(hasElongatedRun).count
        let elongationScore = min(Double(elongatedCount) / wordCount * 25, 1.0)

        // Mean sentence length: short choppy sentences read agitated, long flowing ones calm.
        let meanLength = wordCount / sentenceCount
        let lengthScore = max(-1.0, min(1.0, (12.0 - meanLength) / 10.0))

        // Fragment ratio, only meaningful once there are a few sentences.
        var fragmentScore = 0.0
        if sentences.count >= 3 {
            let fragments = sentences.filter { $0.split(whereSeparator: \.isWhitespace).count <= 3 }.count
            fragmentScore = Double(fragments) / sentenceCount
        }

        // Ellipses pull toward the dull end.
        let ellipsisCount = text.components(separatedBy: "...").count - 1 + text.filter { $0 == "…" }.count
        let ellipsisScore = min(Double(ellipsisCount) / sentenceCount, 1.0)

        let questionScore = min(Double(text.filter { $0 == "?" }.count) / sentenceCount, 1.0)

        // Strongly worded text scores near ±1 on sentiment; that intensity is itself arousal.
        let intensityScore = abs(valence)

        let interjectionScore = min(Double(interjectionCount(in: text)) / wordCount * 15, 1.0)

        // isEmojiPresentation misses emoji that need a variation selector (e.g. ❤️); rough draft.
        let emojiCount = text.unicodeScalars.filter {
            $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value >= 0x1F000)
        }.count
        let emojiScore = min(Double(emojiCount) / sentenceCount, 1.0)

        let raw = 3.0 * exclamationScore
            + 2.5 * capsScore
            + 1.5 * elongationScore
            + 1.5 * lengthScore
            + 0.0 * fragmentScore
            - 2.0 * ellipsisScore
            + 0.75 * questionScore
            + 0.0 * intensityScore
            + 0.75 * interjectionScore
            + 0.5 * emojiScore

        return max(-1.0, min(1.0, raw / 2.0))
    }

    private static func sentenceStrings(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }
        return sentences
    }

    private static func hasElongatedRun(_ word: String) -> Bool {
        var previous: Character?
        var runLength = 1
        for character in word.lowercased() {
            guard character.isLetter else {
                previous = nil
                runLength = 1
                continue
            }
            if character == previous {
                runLength += 1
                if runLength >= 3 { return true }
            } else {
                previous = character
                runLength = 1
            }
        }
        return false
    }

    private static func interjectionCount(in text: String) -> Int {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var count = 0
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitPunctuation, .omitWhitespace]) { tag, _ in
            if tag == .interjection {
                count += 1
            }
            return true
        }
        return count
    }

    // MARK: - Result

    private static func distanceSquared(_ mood: AnchoredMood, valence: Double, arousal: Double) -> Double {
        let dv = mood.valence - valence
        let da = mood.arousal - arousal
        return dv * dv + da * da
    }

    private static func reasonText(valence: Double, arousal: Double) -> String {
        let valenceWord: String
        switch valence {
        case ..<(-0.2): valenceWord = "heavier"
        case 0.2...: valenceWord = "brighter"
        default: valenceWord = "even-keeled"
        }
        let arousalWord: String
        switch arousal {
        case ..<(-0.2): arousalWord = "quiet"
        case 0.2...: arousalWord = "high-energy"
        default: arousalWord = "steady"
        }
        return "The writing reads \(valenceWord) and \(arousalWord)."
    }
}
