import SwiftUI

struct ComposeEntryView: View {
    @ObservedObject var viewModel: DaybookViewModel
    @FocusState private var isEditorFocused: Bool
    @State private var isMoodSheetPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
                SectionHeading(title: viewModel.dailyHeading, detail: "today's line")

            Text("This date becomes read-only after sealing. Keep only what you want to carry forward.")
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundStyle(EditorialPalette.muted)
                .padding(.vertical, 18)

            TextEditor(text: Binding(
                get: { viewModel.draft.text },
                set: { newValue in
                    viewModel.updateDraftText(newValue)
                }
            ))
            .scrollContentBackground(.hidden)
            .font(.system(size: 20, weight: .regular, design: .serif))
            .foregroundStyle(EditorialPalette.inkSoft)
                .frame(minHeight: 459, maxHeight: .infinity, alignment: .topLeading)
            .padding(.vertical, 12)
            .background(alignment: .bottom) {
                EditorialRule()
            }
            .focused($isEditorFocused)

            HStack {
                Text("Write once, keep forever")
                    .font(.system(size: 10, weight: .regular, design: .default))
                    .foregroundStyle(EditorialPalette.muted)
                    .textCase(.uppercase)
                    .tracking(0.9)

                Spacer()

                Button("Seal entry") {
                    isMoodSheetPresented = true
                }
                .buttonStyle(EditorialPrimaryButtonStyle())
                .disabled(viewModel.draft.text.trimmed().isEmpty)
            }
            .padding(.top, 16)
        }
        .sheet(isPresented: $isMoodSheetPresented) {
            MoodSelectionSheet(viewModel: viewModel)
        }
        .onAppear {
            viewModel.updateDraftText(viewModel.draft.text)
            focusEditorSoon()
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            focusEditorSoon()
        }
    }

    private func focusEditorSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isEditorFocused = true
        }
    }
}

private struct MoodSelectionSheet: View {
    @ObservedObject var viewModel: DaybookViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var moodLabel: String
    @State private var moodColorHex: String
    @State private var moodIcon: String
    @State private var isConfirmingSeal = false

    init(viewModel: DaybookViewModel) {
        self.viewModel = viewModel
        let currentMood = viewModel.draft.moodCard
        _moodLabel = State(initialValue: currentMood?.label ?? viewModel.customMoodLabel)
        _moodColorHex = State(initialValue: currentMood?.colorHex ?? viewModel.customMoodColorHex)
        _moodIcon = State(initialValue: currentMood?.icon ?? viewModel.customMoodIcon)
    }

    private var selectedMood: MoodCard? {
        let label = moodLabel.trimmed()
        guard !label.isEmpty else { return nil }

        return MoodCard(
            label: label,
            colorHex: moodColorHex,
            icon: moodIcon.trimmed().isEmpty ? "tag.fill" : moodIcon.trimmed()
        )
    }

    var body: some View {
        ZStack {
            EditorialBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Choose a mood")
                                .font(.system(size: 22, weight: .medium, design: .serif))
                            Text("THE MOOD IS OPTIONAL. SEALING CANNOT BE UNDONE.")
                                .font(.system(size: 10, weight: .regular, design: .default))
                                .foregroundStyle(EditorialPalette.muted)
                                .tracking(1)
                        }

                        Spacer()

                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(EditorialTextButtonStyle())
                    }
                    .padding(.bottom, 16)

                    EditorialRule()

                    Text("Choose a suggestion, use a card, or make one of your own. Leave the mood label blank to seal this day without a mood.")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundStyle(EditorialPalette.muted)
                        .padding(.vertical, 18)

                    SectionHeading(title: "Suggested moods", detail: "from your words")

                    VStack(spacing: 8) {
                        ForEach(Array(viewModel.suggestions.enumerated()), id: \.offset) { _, suggestion in
                            Button {
                                select(suggestion.card)
                            } label: {
                                SuggestedMoodRow(
                                    suggestion: suggestion,
                                    isSelected: selectedMood == suggestion.card
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 12)

                    SectionHeading(title: "Mood cards", detail: "today's palette")

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                        spacing: 8
                    ) {
                        ForEach(viewModel.presets) { preset in
                            Button {
                                select(preset.card)
                            } label: {
                                PresetTile(preset: preset, isSelected: selectedMood == preset.card)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 12)

                    SectionHeading(title: "Custom mood", detail: "make it yours")

                    TextField("Mood label (optional)", text: $moodLabel)
                        .textFieldStyle(EditorialTextFieldStyle())
                        .padding(.top, 8)

                    HStack(spacing: 10) {
                        if let selectedMood {
                            HStack(spacing: 7) {
                                Circle()
                                    .fill(Color(hex: selectedMood.colorHex))
                                    .frame(width: 8, height: 8)
                                Text(selectedMood.label)
                                    .font(.system(size: 12, weight: .medium, design: .default))
                            }
                            .foregroundStyle(EditorialPalette.ink)
                        } else {
                            Text("No mood will be saved")
                                .font(.system(size: 12, weight: .regular, design: .default))
                                .foregroundStyle(EditorialPalette.muted)
                        }

                        Spacer()

                        Button("Seal entry") {
                            isConfirmingSeal = true
                        }
                        .buttonStyle(EditorialPrimaryButtonStyle())
                        .disabled(viewModel.draft.text.trimmed().isEmpty)
                    }
                    .padding(.top, 22)
                }
                .padding(28)
            }
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 690, idealHeight: 760)
        .confirmationDialog(
            "Seal this day?",
            isPresented: $isConfirmingSeal,
            titleVisibility: .visible
        ) {
            Button("Seal entry", role: .destructive) {
                if viewModel.sealSelectedDate(with: selectedMood) {
                    dismiss()
                }
            }
            Button("Keep writing", role: .cancel) {}
        } message: {
            Text("Once sealed, this day becomes read-only. It cannot be edited or deleted.")
        }
    }

    private func select(_ mood: MoodCard) {
        moodLabel = mood.label
        moodColorHex = mood.colorHex
        moodIcon = mood.icon
    }
}

private struct SuggestedMoodRow: View {
    let suggestion: MoodSuggestion
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color(hex: suggestion.card.colorHex))
                .frame(width: 7, height: 7)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.card.label)
                    .font(.system(size: 12, weight: .medium, design: .default))
                Text(suggestion.reason)
                    .font(.system(size: 10, weight: .regular, design: .default))
                    .foregroundStyle(EditorialPalette.ink.opacity(0.67))
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(EditorialPalette.ink)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Rectangle()
                .fill(Color(hex: suggestion.card.colorHex).opacity(isSelected ? 0.42 : 0.28))
                .overlay(EditorialScanlines())
                .overlay(Rectangle().stroke(isSelected ? EditorialPalette.ink : EditorialPalette.rule, lineWidth: isSelected ? 2 : 1))
        }
    }
}

struct SectionHeading: View {
    let title: String
    let detail: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .default))
            Spacer()
            Text(detail)
                .font(.system(size: 10, weight: .regular, design: .default))
                .foregroundStyle(EditorialPalette.muted)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) {
            EditorialRule()
        }
        .overlay(alignment: .bottom) {
            EditorialRule()
        }
    }
}

private struct PresetTile: View {
    let preset: MoodPreset
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(preset.label)
                    .font(.system(size: 10, weight: .medium, design: .default))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            Spacer()
            Image(systemName: preset.icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(EditorialPalette.ink.opacity(0.62))
        }
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background {
            Rectangle()
                .fill(Color(hex: preset.colorHex).opacity(isSelected ? 0.56 : 0.42))
                .overlay(EditorialScanlines())
                .overlay(Rectangle().stroke(isSelected ? EditorialPalette.ink : EditorialPalette.rule, lineWidth: isSelected ? 2 : 1))
        }
    }
}
