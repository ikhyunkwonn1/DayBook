import Foundation

protocol DailyHeadingProviding {
    func heading(for date: Date, calendar: Calendar) -> String
    func futureHeading(for date: Date, calendar: Calendar) -> String
}

struct DailyHeadingService: DailyHeadingProviding {
    func futureHeading(for date: Date, calendar: Calendar) -> String {
        let selectedDate = calendar.startOfDay(for: date)
        let index = stableIndex(
            for: selectedDate,
            calendar: calendar,
            count: Self.futureHeadings.count,
            salt: "future"
        )
        return Self.futureHeadings[index]
    }

    func heading(for date: Date, calendar: Calendar) -> String {
        let selectedDate = calendar.startOfDay(for: date)
        let candidate = baseHeading(for: selectedDate, calendar: calendar)
        let priorHeadings = priorHeadings(for: selectedDate, calendar: calendar)

        guard !priorHeadings.contains(candidate) else {
            let available = Self.headings.flatMap { $0 }.filter { !priorHeadings.contains($0) }
            return available[stableIndex(for: selectedDate, calendar: calendar, count: available.count, salt: "fallback")]
        }

        return candidate
    }

    private func priorHeadings(for date: Date, calendar: Calendar) -> Set<String> {
        let priorDates = (1...2).compactMap { calendar.date(byAdding: .day, value: -$0, to: date) }
        return Set(priorDates.map { baseHeading(for: $0, calendar: calendar) })
    }

    private func baseHeading(for date: Date, calendar: Calendar) -> String {
        let dayNumber = calendar.ordinality(of: .day, in: .era, for: date)
            ?? Int(date.timeIntervalSinceReferenceDate / 86_400)
        let groupIndex = positiveRemainder(dayNumber, divisor: Self.headings.count)
        let group = Self.headings[groupIndex]
        return group[stableIndex(for: date, calendar: calendar, count: group.count, salt: "daily")]
    }

    private func stableIndex(for date: Date, calendar: Calendar, count: Int, salt: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let key = "\(date.diaryKey(calendar: calendar)):\(salt)"

        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        return Int(hash % UInt64(count))
    }

    private func positiveRemainder(_ value: Int, divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }

    private static let futureHeadings: [String] = [
        "The future is a page the ink hasn't found yet.",
        "Somewhere ahead, this day is still deciding what it will be.",
        "No one has written this day. Not even you.",
        "This one is still being imagined.",
        "Tomorrow keeps its secrets. Come back when it tells you one.",
        "The day is still on its way to you.",
        "Let it arrive first. It will bring its own words.",
        "Some days are still walking toward you.",
        "Wait for the day to arrive, then let it leave a mark."
    ]

    // Each group is disjoint so a line cannot recur on either of the next two days.
    private static let headings: [[String]] = [
        [
            "Leave a little evidence of today.",
            "Keep a small record of being here.",
            "Put the ordinary somewhere safe.",
            "Name what stayed with you.",
            "Save one true thing.",
            "Let the day leave a mark.",
            "Collect the pieces that mattered.",
            "Write down what you noticed.",
            "Keep the soft details.",
            "Hold this moment still.",
            "Make a home for the passing thought.",
            "Let the small things count.",
            "Leave a note for your future self.",
            "Remember the shape of this day.",
            "Keep the weather of your mind.",
            "Set this day gently aside."
        ],
        [
            "Make room for the unfinished.",
            "Write it down before it blurs.",
            "Let the day be enough.",
            "Start with the smallest truth.",
            "Follow the thread that remains.",
            "Give the loose ends a place to land.",
            "Say it plainly, then let it rest.",
            "Begin anywhere.",
            "Write around the thing you cannot name.",
            "Let the first sentence be imperfect.",
            "Keep going until the room gets quiet.",
            "Put a little light on it.",
            "Find the sentence waiting underneath.",
            "Leave the door open for tomorrow.",
            "Write what asks to be kept.",
            "Let the page hold the weight."
        ],
        [
            "Keep what you want to remember.",
            "Take your time with the truth.",
            "Set down the noise.",
            "Let this be a private kind of proof.",
            "Notice what changed.",
            "Keep the part that felt alive.",
            "Give today a place to return to.",
            "Write the version only you know.",
            "Let a quiet thought have its turn.",
            "Make a small archive of wonder.",
            "Say what the day sounded like.",
            "Keep the spark, not the summary.",
            "Let the details stay detailed.",
            "Write from where you are.",
            "Let this moment be unfinished.",
            "Save the feeling before it moves."
        ]
    ]
}
