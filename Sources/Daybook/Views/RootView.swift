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

private struct CalendarSidebarView: View {
    @ObservedObject var viewModel: DaybookViewModel

    private let weekdaySymbols = Calendar.current.shortStandaloneWeekdaySymbols

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
                    }
                    .buttonStyle(EditorialTextButtonStyle())
                }
                .padding(.bottom, 20)

                EditorialRule()

                HStack {
                    Button {
                        viewModel.showPreviousMonth()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(EditorialIconButtonStyle())

                    Spacer()

                    Text(viewModel.monthTitle)
                        .font(.system(size: 15, weight: .medium, design: .default))

                    Spacer()

                    Button {
                        viewModel.showNextMonth()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(EditorialIconButtonStyle())
                }
                .padding(.vertical, 10)

                EditorialRule()

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 7), spacing: 7) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol.uppercased())
                            .font(.system(size: 9, weight: .medium, design: .default))
                            .foregroundStyle(EditorialPalette.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }

                    ForEach(viewModel.calendarDays) { day in
                        DayCell(
                            day: day,
                            isSelected: viewModel.calendar.isDate(day.date, inSameDayAs: viewModel.selectedDate),
                            entry: viewModel.entries.first { viewModel.calendar.isDate($0.date, inSameDayAs: day.date) }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectDate(day.date)
                        }
                    }
                }
                .padding(.top, 2)

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
                            ForEach(viewModel.entries.prefix(8)) { entry in
                                EntryPreviewCard(entry: entry)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewModel.displayedMonth = entry.date
                                        viewModel.selectDate(entry.date)
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

private struct DayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let entry: SealedDiaryEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(day.date.formatted(.dateTime.day()))
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(day.isInDisplayedMonth ? EditorialPalette.ink : EditorialPalette.muted.opacity(0.5))

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
                } else {
                    Text("Hover the lines to let the day move.")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundStyle(EditorialPalette.muted)
                }
            }
            .padding(.top, 16)
        }
    }
}
