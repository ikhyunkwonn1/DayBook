import Foundation
import SwiftUI

struct MoodCard: Codable, Equatable {
    var label: String
    var colorHex: String
    var icon: String
}

struct DiaryEntryDraft: Codable, Equatable {
    var date: Date
    var text: String = ""
    var moodCard: MoodCard?
}

struct SealedDiaryEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var date: Date
    var sealedAt: Date
    var archiveFileName: String
    var archiveByteCount: Int
    var preview: String
    var moodCard: MoodCard?
}

struct ArchivedEntryPayload: Codable, Equatable {
    var id: UUID
    var date: Date
    var sealedAt: Date
    var text: String
    var moodCard: MoodCard?
}

struct CalendarDay: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let isInDisplayedMonth: Bool
}

struct MonthID: Hashable, Identifiable {
    let year: Int
    let month: Int

    var id: Self { self }

    init(date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month], from: date)
        self.year = components.year ?? 1
        self.month = components.month ?? 1
    }

    func startDate(calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    func title(calendar: Calendar) -> String {
        startDate(calendar: calendar).formatted(.dateTime.month(.wide).year())
    }

    static func range(around date: Date, radius: Int, calendar: Calendar) -> [MonthID] {
        (-radius...radius).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: date)
                .map { MonthID(date: $0, calendar: calendar) }
        }
    }
}

struct MoodSuggestion: Equatable {
    var card: MoodCard
    var reason: String
}

struct MoodPreset: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let colorHex: String
    let icon: String

    var card: MoodCard {
        MoodCard(label: label, colorHex: colorHex, icon: icon)
    }
}

enum DiaryError: LocalizedError {
    case alreadySealed
    case entryNotFound
    case emptyText
    case futureDate
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .alreadySealed:
            return "This date is already sealed and cannot be changed."
        case .entryNotFound:
            return "The archived entry could not be found."
        case .emptyText:
            return "Write something before sealing the entry."
        case .futureDate:
            return "Some days are still on their way. This one cannot be sealed yet."
        case .exportFailed:
            return "The archive could not be exported."
        }
    }
}

extension MoodPreset {
    static let defaults: [MoodPreset] = [
        MoodPreset(label: "Calm", colorHex: "#8A9A7B", icon: "leaf.fill"),
        MoodPreset(label: "Bright", colorHex: "#D68653", icon: "sun.max.fill"),
        MoodPreset(label: "Tender", colorHex: "#B56576", icon: "heart.fill"),
        MoodPreset(label: "Restless", colorHex: "#546A7B", icon: "wind"),
        MoodPreset(label: "Focused", colorHex: "#567C8D", icon: "pencil.line"),
        MoodPreset(label: "Dreamy", colorHex: "#7E6B8F", icon: "moon.stars.fill")
    ]
}

extension Date {
    func diaryKey(calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: self)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func previewText(limit: Int = 80) -> String {
        let normalized = replacingOccurrences(of: "\n", with: " ").trimmed()
        guard normalized.count > limit else { return normalized }
        return String(normalized.prefix(limit)).trimmed() + "..."
    }
}

extension Color {
    init(hex: String) {
        let sanitized = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
