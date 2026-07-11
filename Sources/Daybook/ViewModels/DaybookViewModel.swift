import AppKit
import Foundation
import SwiftUI

@MainActor
final class DaybookViewModel: ObservableObject {
    @Published var displayedMonth: Date
    @Published var selectedDate: Date
    @Published var draft: DiaryEntryDraft
    @Published var entries: [SealedDiaryEntry] = []
    @Published var selectedEntryPayload: ArchivedEntryPayload?
    @Published var suggestions: [MoodSuggestion] = []
    @Published var customMoodLabel: String = ""
    @Published var customMoodColorHex: String = "#8A9A7B"
    @Published var customMoodIcon: String = "leaf.fill"
    @Published var errorMessage: String?
    @Published var statusMessage: String = "A quiet place for sealed days."
    @Published private(set) var dailyHeading: String

    let calendar: Calendar
    let presets = MoodPreset.defaults

    private let archiveStore: ArchiveStore
    private let suggestionService: MoodSuggestionService
    private let dailyHeadingService: DailyHeadingProviding

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
        self.displayedMonth = today
        self.selectedDate = today
        self.draft = DiaryEntryDraft(date: today)
        self.dailyHeading = dailyHeadingService.heading(for: today, calendar: calendar)

        reloadEntries()
        selectDate(today)
    }

    var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    var selectedEntry: SealedDiaryEntry? {
        entries.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var calendarDays: [CalendarDay] {
        let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) ?? DateInterval()
        let firstDay = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -offset, to: firstDay) ?? firstDay

        return (0..<42).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index, to: gridStart) else { return nil }
            return CalendarDay(
                date: date,
                isInDisplayedMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
            )
        }
    }

    func selectDate(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
        dailyHeading = dailyHeadingService.heading(for: selectedDate, calendar: calendar)
        draft = DiaryEntryDraft(date: selectedDate)
        selectedEntryPayload = nil
        suggestions = suggestionService.suggest(for: "")
        customMoodLabel = ""
        customMoodColorHex = "#8A9A7B"
        customMoodIcon = "leaf.fill"

        if let entry = selectedEntry {
            loadPayload(for: entry)
            statusMessage = "Sealed on \(entry.sealedAt.formatted(date: .abbreviated, time: .shortened))."
        } else {
            statusMessage = "Drafting for \(selectedDate.formatted(date: .long, time: .omitted))."
        }
    }

    func showPreviousMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
    }

    func showNextMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
    }

    func jumpToToday() {
        let today = calendar.startOfDay(for: Date())
        displayedMonth = today
        selectDate(today)
    }

    func updateDraftText(_ text: String) {
        draft.text = text
        suggestions = suggestionService.suggest(for: text)
    }

    func sealSelectedDate(with moodCard: MoodCard?) {
        draft.moodCard = moodCard

        do {
            let entry = try archiveStore.create(from: draft)
            errorMessage = nil
            reloadEntries()
            selectDate(entry.date)
        } catch {
            errorMessage = error.localizedDescription
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
