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
    func futureDatesCannotBeSealed() throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = LocalArchiveStore(rootURL: rootURL)
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        #expect(throws: DiaryError.futureDate) {
            _ = try store.create(from: DiaryEntryDraft(date: tomorrow, text: "A day that has not happened."))
        }

        let entry = try store.create(from: DiaryEntryDraft(date: today, text: "A day that has."))
        #expect(Calendar.current.isDate(entry.date, inSameDayAs: today))
    }

    @Test
    func futureHeadingIsStableForAGivenDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let service = DailyHeadingService()
        let date = calendar.date(from: DateComponents(year: 2026, month: 7, day: 20))!

        let heading = service.futureHeading(for: date, calendar: calendar)
        #expect(service.futureHeading(for: date, calendar: calendar) == heading)
        #expect(heading.isEmpty == false)
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

        #expect(viewModel.entry(on: date)?.moodCard == nil)

        let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        viewModel.selectDate(previousDate)
        viewModel.updateDraftText("Yesterday I made steady progress.")
        let focused = MoodPreset.defaults.first { $0.label == "Focused" }!.card
        viewModel.sealSelectedDate(with: focused)

        #expect(viewModel.entry(on: previousDate)?.moodCard == focused)
    }

    @MainActor
    @Test
    func weekdaySymbolsRotateToMatchFirstWeekday() {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

        var sundayFirst = Calendar(identifier: .gregorian)
        sundayFirst.locale = Locale(identifier: "en_US")
        sundayFirst.firstWeekday = 1

        var mondayFirst = Calendar(identifier: .gregorian)
        mondayFirst.locale = Locale(identifier: "en_US")
        mondayFirst.firstWeekday = 2

        let sundayModel = DaybookViewModel(calendar: sundayFirst, archiveStore: LocalArchiveStore(rootURL: rootURL))
        let mondayModel = DaybookViewModel(calendar: mondayFirst, archiveStore: LocalArchiveStore(rootURL: rootURL))

        // The grid rotates its columns by firstWeekday, so the header must rotate with it.
        #expect(sundayModel.orderedWeekdaySymbols.first == "Sun")
        #expect(mondayModel.orderedWeekdaySymbols.first == "Mon")
        #expect(mondayModel.orderedWeekdaySymbols.last == "Sun")
        #expect(mondayModel.orderedWeekdaySymbols.count == 7)
    }

    @Test
    func moodSuggestionsMatchWholeWordsNotSubstrings() {
        let service = LocalMoodSuggestionService()

        // "chocolate" contains "late", "restaurant" contains "rest" — neither is a real match now,
        // so both fall through to the default presets rather than claiming to read the text.
        #expect(service.suggest(for: "I ate chocolate").contains { $0.card.label == "Restless" } == false)

        let restaurant = service.suggest(for: "We went to a restaurant")
        #expect(restaurant.allSatisfy { $0.reason.contains("default") })

        // "stressed" used to match both "rest" (Calm) and "stress" (Restless).
        let stressed = service.suggest(for: "I felt stress all day")
        #expect(stressed.contains { $0.card.label == "Restless" })
        #expect(stressed.contains { $0.card.label == "Calm" } == false)

        // Real whole-word hits still work.
        #expect(service.suggest(for: "a quiet gentle walk").first?.card.label == "Calm")
    }

    @MainActor
    @Test
    func draftSurvivesNavigatingBetweenDays() {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let viewModel = DaybookViewModel(archiveStore: LocalArchiveStore(rootURL: rootURL))
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        viewModel.updateDraftText("Half a page I have not sealed yet.")
        viewModel.selectDate(yesterday)
        #expect(viewModel.draft.text.isEmpty)

        viewModel.selectDate(today)
        #expect(viewModel.draft.text == "Half a page I have not sealed yet.")

        // The Today button used to wipe the draft even when today was already selected.
        viewModel.jumpToToday()
        #expect(viewModel.draft.text == "Half a page I have not sealed yet.")
    }

    @MainActor
    @Test
    func sealingPurgesThatDaysDraft() throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = LocalArchiveStore(rootURL: rootURL)
        let viewModel = DaybookViewModel(archiveStore: store)
        let today = Calendar.current.startOfDay(for: Date())

        viewModel.updateDraftText("A day worth keeping.")
        #expect(viewModel.sealSelectedDate(with: nil))

        // A surviving draft would resurrect on a day that is now read-only.
        #expect(try store.loadDrafts()[today.diaryKey(calendar: .current)] == nil)
        #expect(viewModel.entry(on: today) != nil)
    }
}
