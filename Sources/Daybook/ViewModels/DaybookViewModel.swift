import AppKit
import Foundation
import SwiftUI

@MainActor
final class DaybookViewModel: ObservableObject {
    @Published var selectedDate: Date
    @Published var draft: DiaryEntryDraft
    @Published var entries: [SealedDiaryEntry] = []
    @Published private(set) var entriesByDay: [String: SealedDiaryEntry] = [:]
    @Published var selectedEntryPayload: ArchivedEntryPayload?
    @Published var suggestions: [MoodSuggestion] = []
    @Published var customMoodLabel: String = ""
    @Published var customMoodColorHex: String = "#8A9A7B"
    @Published var customMoodIcon: String = "leaf.fill"
    @Published var errorMessage: String?
    @Published var statusMessage: String = "A quiet place for sealed days."
    @Published private(set) var dailyHeading: String
    @Published private(set) var draftSavedAt: Date?

    let calendar: Calendar
    let presets = MoodPreset.defaults

    private let archiveStore: ArchiveStore
    private let suggestionService: MoodSuggestionService
    private let dailyHeadingService: DailyHeadingProviding

    private var drafts: [String: DiaryEntryDraft] = [:]
    private var autosaveTask: Task<Void, Never>?

    init(
        calendar: Calendar = .current,
        archiveStore: ArchiveStore = LocalArchiveStore(),
        suggestionService: MoodSuggestionService = LocalMoodSuggestionService(),
        dailyHeadingService: DailyHeadingProviding = DailyHeadingService()
    ) {
        let today = calendar.startOfDay(for: Date())
        self.calendar = calendar
        self.archiveStore = archiveStore
        self.suggestionService = suggestionService
        self.dailyHeadingService = dailyHeadingService
        self.selectedDate = today
        self.draft = DiaryEntryDraft(date: today)
        self.dailyHeading = dailyHeadingService.heading(for: today, calendar: calendar)

        reloadEntries()
        drafts = (try? archiveStore.loadDrafts()) ?? [:]
        selectDate(today)
    }

    var orderedWeekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    var selectedEntry: SealedDiaryEntry? {
        entries.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var isSelectedDateInFuture: Bool {
        selectedDate > calendar.startOfDay(for: Date())
    }

    func entry(on date: Date) -> SealedDiaryEntry? {
        entriesByDay[date.diaryKey(calendar: calendar)]
    }

    func calendarDays(for month: MonthID) -> [CalendarDay] {
        let monthStart = month.startDate(calendar: calendar)
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -offset, to: monthStart) ?? monthStart

        return (0..<42).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index, to: gridStart) else { return nil }
            return CalendarDay(
                date: date,
                isInDisplayedMonth: calendar.isDate(date, equalTo: monthStart, toGranularity: .month)
            )
        }
    }

    func selectDate(_ date: Date) {
        stashCurrentDraft()

        errorMessage = nil
        selectedDate = calendar.startOfDay(for: date)
        draft = drafts[selectedDate.diaryKey(calendar: calendar)] ?? DiaryEntryDraft(date: selectedDate)
        selectedEntryPayload = nil
        suggestions = suggestionService.suggest(for: draft.text)
        customMoodLabel = ""
        customMoodColorHex = "#8A9A7B"
        customMoodIcon = "leaf.fill"

        if isSelectedDateInFuture {
            dailyHeading = dailyHeadingService.futureHeading(for: selectedDate, calendar: calendar)
        } else {
            dailyHeading = dailyHeadingService.heading(for: selectedDate, calendar: calendar)
        }

        if let entry = selectedEntry {
            loadPayload(for: entry)
            statusMessage = "Sealed on \(entry.sealedAt.formatted(date: .abbreviated, time: .shortened))."
        } else if isSelectedDateInFuture {
            statusMessage = "Not yet written."
        } else {
            statusMessage = "Drafting for \(selectedDate.formatted(date: .long, time: .omitted))."
        }
    }

    func jumpToToday() {
        selectDate(calendar.startOfDay(for: Date()))
    }

    func updateDraftText(_ text: String) {
        draft.text = text
        suggestions = suggestionService.suggest(for: text)
        scheduleAutosave()
    }

    /// Keeps the in-progress draft for the day we are leaving, so navigating away never destroys it.
    private func stashCurrentDraft() {
        let key = draft.date.diaryKey(calendar: calendar)
        drafts[key] = draft.text.trimmed().isEmpty ? nil : draft
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self else { return }
            self.persistDrafts()
        }
    }

    private func persistDrafts() {
        stashCurrentDraft()
        do {
            try archiveStore.saveDrafts(drafts)
            draftSavedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func sealSelectedDate(with moodCard: MoodCard?) -> Bool {
        draft.moodCard = moodCard

        do {
            let entry = try archiveStore.create(from: draft)
            errorMessage = nil

            // The day is sealed: drop its draft, or it would resurrect on a read-only day.
            autosaveTask?.cancel()
            drafts[entry.date.diaryKey(calendar: calendar)] = nil
            draft.text = ""
            try? archiveStore.saveDrafts(drafts)

            reloadEntries()
            selectDate(entry.date)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func exportSelectedEntry() {
        guard let entry = selectedEntry else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.data]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = entry.archiveFileName

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try archiveStore.export(entry: entry, to: url)
            statusMessage = "Archived file exported."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadEntries() {
        do {
            entries = try archiveStore.listEntries()
            entriesByDay = Dictionary(
                entries.map { ($0.date.diaryKey(calendar: calendar), $0) },
                uniquingKeysWith: { first, _ in first }
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPayload(for entry: SealedDiaryEntry) {
        do {
            selectedEntryPayload = try archiveStore.readPayload(for: entry)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
