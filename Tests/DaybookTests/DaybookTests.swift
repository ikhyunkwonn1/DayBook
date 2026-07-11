import Foundation
import Testing
@testable import Daybook

struct DaybookTests {
    @Test
    func sealingCreatesImmutableArchive() throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = LocalArchiveStore(rootURL: rootURL)
        let date = Calendar.current.startOfDay(for: Date())
        let draft = DiaryEntryDraft(
            date: date,
            text: "Today I built a retro diary app and it felt focused.",
            moodCard: MoodCard(label: "Focused", colorHex: "#567C8D", icon: "pencil.line")
        )

        let entry = try store.create(from: draft)
        let payload = try store.readPayload(for: entry)

        #expect(payload.text == draft.text)
        #expect(entry.preview.contains("retro diary app"))
        #expect(throws: DiaryError.self) {
            _ = try store.create(from: draft)
        }
    }

    @Test
    func localSuggestionEngineFallsBackToDefaults() {
        let service = LocalMoodSuggestionService()
        let suggestions = service.suggest(for: "A very ordinary afternoon.")

        #expect(suggestions.count == 3)
        #expect(suggestions[0].card.label == "Calm")
    }

    @Test
    func dailyHeadingIsStableAndDoesNotRepeatWithinTwoDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let service = DailyHeadingService()
        let firstDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))!
        var headings: [String] = []

        for offset in 0..<60 {
            let date = calendar.date(byAdding: .day, value: offset, to: firstDate)!
            headings.append(service.heading(for: date, calendar: calendar))
        }

        #expect(service.heading(for: firstDate, calendar: calendar) == headings[0])
        for index in 1..<headings.count {
            #expect(headings[index] != headings[index - 1])
            if index > 1 {
                #expect(headings[index] != headings[index - 2])
            }
        }
    }

    @MainActor
    @Test
    func sealingFromMoodSheetSupportsOptionalAndSelectedMoods() throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = LocalArchiveStore(rootURL: rootURL)
        let date = Calendar.current.startOfDay(for: Date())
        let viewModel = DaybookViewModel(archiveStore: store)

        viewModel.updateDraftText("A diary entry without a selected mood.")
        viewModel.sealSelectedDate(with: nil)

        #expect(viewModel.entries.first?.moodCard == nil)

        let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        viewModel.selectDate(nextDate)
        viewModel.updateDraftText("Today I made steady progress.")
        let focused = MoodPreset.defaults.first { $0.label == "Focused" }!.card
        viewModel.sealSelectedDate(with: focused)

        #expect(viewModel.entries.first?.moodCard == focused)
    }
}
