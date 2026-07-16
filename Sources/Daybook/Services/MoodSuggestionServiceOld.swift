import Foundation

struct LocalMoodSuggestionService: MoodSuggestionService {
    private let mappings: [KeywordMoodMapping] = [
        KeywordMoodMapping(
            keywords: ["calm", "quiet", "gentle", "rest", "walk", "tea", "breeze"],
            suggestion: MoodSuggestion(
                card: MoodCard(label: "Calm", colorHex: "#8A9A7B", icon: "leaf.fill"),
                reason: "Soft, restful language often points to a calm day."
            )
        ),
        KeywordMoodMapping(
            keywords: ["happy", "bright", "laugh", "joy", "sunny", "good", "celebrate"],
            suggestion: MoodSuggestion(
                card: MoodCard(label: "Bright", colorHex: "#D68653", icon: "sun.max.fill"),
                reason: "The draft reads upbeat and energetic."
            )
        ),
        KeywordMoodMapping(
            keywords: ["love", "care", "family", "friend", "together", "miss", "warm"],
            suggestion: MoodSuggestion(
                card: MoodCard(label: "Tender", colorHex: "#B56576", icon: "heart.fill"),
                reason: "Relational or affectionate phrasing suggests a tender tone."
            )
        ),
        KeywordMoodMapping(
            keywords: ["busy", "anxious", "late", "tired", "stress", "mess", "worry"],
            suggestion: MoodSuggestion(
                card: MoodCard(label: "Restless", colorHex: "#546A7B", icon: "wind"),
                reason: "The language suggests motion, pressure, or unease."
            )
        ),
        KeywordMoodMapping(
            keywords: ["made", "learned", "worked", "study", "built", "focused", "progress"],
            suggestion: MoodSuggestion(
                card: MoodCard(label: "Focused", colorHex: "#567C8D", icon: "pencil.line"),
                reason: "The draft leans toward creation or concentration."
            )
        )
    ]

    func suggest(for text: String) -> [MoodSuggestion] {
        // Whole words only: substring matching made "chocolate" restless and "restaurant" calm.
        let words = Set(text.lowercased().split { !$0.isLetter }.map(String.init))
        let ranked = mappings.compactMap { mapping -> (MoodSuggestion, Int)? in
            let matches = mapping.keywords.reduce(into: 0) { count, keyword in
                if words.contains(keyword) {
                    count += 1
                }
            }
            guard matches > 0 else { return nil }
            return (mapping.suggestion, matches)
        }
        .sorted { $0.1 > $1.1 }
        .map(\.0)

        if ranked.isEmpty {
            return MoodPreset.defaults.prefix(1).map {
                MoodSuggestion(card: $0.card, reason: "A default preset for when the text gives no strong signal.")
            }
        }

        return Array(ranked.prefix(1))
    }
}

private struct KeywordMoodMapping {
    let keywords: [String]
    let suggestion: MoodSuggestion
}
