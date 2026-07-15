import SwiftUI

struct RootView: View {
    @ObservedObject var viewModel: DaybookViewModel

    var body: some View {
        NavigationSplitView {
            CalendarSidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 350, ideal: 390)
        } detail: {
            ZStack {
                EditorialBackdrop()

                ScrollView {
                    VStack(spacing: 34) {
                        HeaderBanner(viewModel: viewModel)

                        if let entry = viewModel.selectedEntry, let payload = viewModel.selectedEntryPayload {
                            SealedEntryView(
                                entry: entry,
                                payload: payload,
                                onExport: viewModel.exportSelectedEntry
                            )
                        } else if viewModel.isSelectedDateInFuture {
                            FutureDayView(viewModel: viewModel)
                        } else {
                            ComposeEntryView(viewModel: viewModel)
                        }
                    }
                    .padding(28)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

private let calendarColumns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 7)
private let monthGridHeight: CGFloat = 6 * 62 + 5 * 7
private let calendarTrailingInset: CGFloat = 12

private struct CalendarSidebarView: View {
    @ObservedObject var viewModel: DaybookViewModel

    private let months = MonthID.range(around: Date(), radius: 600, calendar: .current)
    private let todayMonth = MonthID(date: Date(), calendar: .current)

    @State private var visibleMonth: MonthID? = MonthID(date: Date(), calendar: .current)
    /// `scrollPosition` reports nil while a scroll is unresolvable; without this the title would
    /// snap back to today's month mid-scroll.
    @State private var lastResolvedMonth = MonthID(date: Date(), calendar: .current)

    var body: some View {
        ZStack {
            EditorialBackdrop()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("daybook")
                            .font(.system(size: 21, weight: .semibold, design: .default))
                        Text("A calendar for private thoughts")
                            .font(.system(size: 10, weight: .regular, design: .default))
                            .foregroundStyle(EditorialPalette.muted)
                            .textCase(.uppercase)
                    }

                    Spacer()

                    Button("Today") {
                        viewModel.jumpToToday()
                        withAnimation(.easeInOut(duration: 0.35)) {
                            visibleMonth = todayMonth
                        }
                    }
                    .buttonStyle(EditorialTextButtonStyle())
                }
                .padding(.bottom, 20)

                EditorialRule()

                Text((visibleMonth ?? lastResolvedMonth).title(calendar: viewModel.calendar))
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)

                EditorialRule()

                LazyVGrid(columns: calendarColumns, spacing: 7) {
                    ForEach(viewModel.orderedWeekdaySymbols, id: \.self) { symbol in
                        Text(symbol.uppercased())
                            .font(.system(size: 9, weight: .medium, design: .default))
                            .foregroundStyle(EditorialPalette.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.trailing, calendarTrailingInset)

                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(months) { month in
                            MonthGrid(viewModel: viewModel, month: month)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $visibleMonth, anchor: .top)
                .scrollIndicators(.never)
                .frame(height: monthGridHeight)
                .overlay(alignment: .top) { ScrollEdgeFade(edge: .top) }
                .overlay(alignment: .bottom) { ScrollEdgeFade(edge: .bottom) }
                .onChange(of: visibleMonth) { _, month in
                    if let month {
                        lastResolvedMonth = month
                    }
                }
                .padding(.top, 2)
                .padding(.trailing, calendarTrailingInset)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Archived days")
                            .font(.system(size: 11, weight: .medium, design: .default))
                        Spacer()
                        Text("recent fragments")
                            .font(.system(size: 10, weight: .regular, design: .default))
                            .foregroundStyle(EditorialPalette.muted)
                    }
                    .padding(.vertical, 14)

                    EditorialRule()

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.entries) { entry in
                                EntryPreviewCard(entry: entry)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewModel.selectDate(entry.date)
                                        withAnimation(.easeInOut(duration: 0.35)) {
                                            visibleMonth = MonthID(date: entry.date, calendar: viewModel.calendar)
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding(.top, 26)
                .frame(maxHeight: .infinity)
            }
            .padding(24)
        }
    }
}

/// Fades the scroller into the paper at its edges, so a calendar with no scrollbar still reads
/// as something that scrolls.
private struct ScrollEdgeFade: View {
    let edge: VerticalEdge

    var body: some View {
        LinearGradient(
            colors: [EditorialPalette.paper, EditorialPalette.paper.opacity(0)],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        .frame(height: 16)
        .allowsHitTesting(false)
    }
}

private struct MonthGrid: View {
    @ObservedObject var viewModel: DaybookViewModel
    let month: MonthID

    var body: some View {
        LazyVGrid(columns: calendarColumns, spacing: 7) {
            ForEach(viewModel.calendarDays(for: month)) { day in
                if day.isInDisplayedMonth {
                    DayCell(
                        day: day,
                        isSelected: viewModel.calendar.isDate(day.date, inSameDayAs: viewModel.selectedDate),
                        isToday: viewModel.calendar.isDateInToday(day.date),
                        entry: viewModel.entry(on: day.date)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectDate(day.date)
                    }
                } else {
                    Color.clear
                        .frame(minHeight: 62)
                }
            }
        }
        // Overlay, never a header row: a real row would change the item height and bring back
        // the launch flash the uniform 42-cell grid exists to prevent.
        .overlay(alignment: .center) {
            Text(month.title(calendar: viewModel.calendar))
                .font(.system(size: 40, weight: .semibold, design: .serif))
                .foregroundStyle(EditorialPalette.ink.opacity(0.06))
                .allowsHitTesting(false)
        }
    }
}

private struct DayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let isToday: Bool
    let entry: SealedDiaryEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(day.date.formatted(.dateTime.day()))
                .font(.system(size: 13, weight: isToday ? .bold : .medium, design: .default))
                .foregroundStyle(EditorialPalette.ink)
                .underline(isToday, color: EditorialPalette.ink)

            Spacer(minLength: 0)

            if let mood = entry?.moodCard {
                Text(mood.label.lowercased())
                    .font(.system(size: 8, weight: .medium, design: .default))
                    .foregroundStyle(EditorialPalette.ink.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
        .background {
            Rectangle()
                .fill(entry.map { Color(hex: $0.moodCard?.colorHex ?? "#F7F7F3").opacity(0.42) } ?? EditorialPalette.paperSoft)
                .overlay {
                    if entry != nil {
                        EditorialScanlines()
                    }
                }
                .overlay {
                    Rectangle()
                        .stroke(isSelected ? EditorialPalette.ink : EditorialPalette.rule, lineWidth: isSelected ? 2 : 1)
                }
        }
    }
}

private struct EntryPreviewCard: View {
    let entry: SealedDiaryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color(hex: entry.moodCard?.colorHex ?? "#85847C"))
                .frame(width: 6, height: 6)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11, weight: .medium, design: .default))

                Text(entry.preview)
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundStyle(EditorialPalette.inkSoft)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            EditorialRule()
        }
    }
}

private struct HeaderBanner: View {
    @ObservedObject var viewModel: DaybookViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("One day at a time")
                    .font(.system(size: 10, weight: .regular, design: .default))
                    .foregroundStyle(EditorialPalette.muted)
                    .textCase(.uppercase)
                    .tracking(1.1)

                Spacer()

                Text(viewModel.statusMessage)
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundStyle(EditorialPalette.muted)
                    .lineLimit(1)
            }
            .padding(.bottom, 14)

            EditorialRule()

            EditorialHeroArt()
                .frame(height: 184)
                .padding(.vertical, 16)

            EditorialRule()

            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.selectedDate.formatted(date: .complete, time: .omitted))
                    .font(.system(size: 25, weight: .medium, design: .default))
                    .tracking(-0.5)

                Spacer()

                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundStyle(EditorialPalette.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(EditorialPalette.warning)
                } else if let savedAt = viewModel.draftSavedAt {
                    Text("Draft saved \(savedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundStyle(EditorialPalette.muted)
                }
            }
            .padding(.top, 16)
        }
    }
}
