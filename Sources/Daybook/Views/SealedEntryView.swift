import SwiftUI

struct SealedEntryView: View {
    let entry: SealedDiaryEntry
    let payload: ArchivedEntryPayload
    let onExport: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 48) {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeading(title: "Sealed archive", detail: "\(entry.archiveByteCount) bytes")

                Text(payload.text)
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundStyle(EditorialPalette.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: 350, alignment: .topLeading)
                    .padding(.vertical, 22)
                    .textSelection(.enabled)

                EditorialRule()

                HStack(alignment: .center) {
                    Text("Immutable file: \(entry.archiveFileName)")
                        .font(.system(size: 10, weight: .regular, design: .default))
                        .foregroundStyle(EditorialPalette.muted)
                        .lineLimit(1)

                    Spacer()

                    Button("Export archive") {
                        onExport()
                    }
                    .buttonStyle(EditorialPrimaryButtonStyle())
                }
                .padding(.top, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeading(title: "Archive card", detail: "sealed")

                    VStack(alignment: .leading, spacing: 16) {
                        StatRow(title: "Sealed", value: entry.sealedAt.formatted(date: .abbreviated, time: .shortened))
                        StatRow(title: "Date", value: entry.date.formatted(date: .complete, time: .omitted))
                        StatRow(title: "Preview", value: entry.preview)
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        Rectangle()
                            .fill(EditorialPalette.paperSoft)
                            .overlay(EditorialScanlines().opacity(0.48))
                            .overlay(Rectangle().stroke(EditorialPalette.rule, lineWidth: 1))
                    }
                    .padding(.top, 10)
                }

                if let mood = payload.moodCard {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeading(title: "Mood card", detail: "archived")

                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: mood.colorHex))
                                .frame(width: 10, height: 10)
                            Label(mood.label, systemImage: mood.icon)
                                .font(.system(size: 13, weight: .medium, design: .default))
                        }
                        .padding(15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            Rectangle()
                                .fill(Color(hex: mood.colorHex).opacity(0.28))
                                .overlay(EditorialScanlines())
                                .overlay(Rectangle().stroke(EditorialPalette.rule, lineWidth: 1))
                        }
                        .padding(.top, 10)
                    }
                }
            }
            .frame(width: 300)
        }
    }
}

private struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .medium, design: .default))
                .foregroundStyle(EditorialPalette.muted)
                .tracking(0.8)
            Text(value)
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundStyle(EditorialPalette.inkSoft)
                .lineLimit(title == "Preview" ? 3 : 2)
        }
    }
}
