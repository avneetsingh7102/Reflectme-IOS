import SwiftUI

/// Full transcript view presented as a sheet from the neural map.
struct TranscriptSheet: View {
    let entry: JournalEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: ReflectTheme.spacingLG) {
                    header
                    Divider().foregroundStyle(ReflectTheme.separator)

                    Text(entry.polishedTranscript.isEmpty ? entry.rawTranscript : entry.polishedTranscript)
                        .font(ReflectTheme.serif(16))
                        .foregroundStyle(ReflectTheme.textPrimary.opacity(0.85))
                        .lineSpacing(7)

                    if !entry.mapNodes.isEmpty {
                        themePills
                    }
                }
                .padding(ReflectTheme.spacingLG)
            }
            .background(ReflectTheme.canvas)
            .navigationTitle("Full transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(ReflectTheme.rounded(16, weight: .semibold))
                        .foregroundStyle(ReflectTheme.accent)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(ReflectTheme.cornerRadiusXL)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ReflectTheme.spacingSM) {
            Text(entry.aiGeneratedTitle)
                .font(ReflectTheme.serif(22, weight: .semibold))
                .foregroundStyle(ReflectTheme.textPrimary)
            HStack(spacing: 8) {
                Image(systemName: "clock").font(.system(size: 11))
                Text(formattedDate).font(ReflectTheme.rounded(13))
            }
            .foregroundStyle(ReflectTheme.textMuted)
        }
    }

    private var themePills: some View {
        VStack(alignment: .leading, spacing: ReflectTheme.spacingSM) {
            Text("Themes")
                .font(ReflectTheme.rounded(11, weight: .bold))
                .foregroundStyle(ReflectTheme.textMuted)
                .textCase(.uppercase)
                .tracking(1.0)
            FlowLayout(spacing: 6) {
                ForEach(entry.mapNodes, id: \.id) { node in
                    Text(node.label)
                        .font(ReflectTheme.rounded(12, weight: .medium))
                        .foregroundStyle(ReflectTheme.textMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(ReflectTheme.separator.opacity(0.5)))
                }
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: entry.date)
    }
}
