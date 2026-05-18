import SwiftUI

/// One card in the journal list: serif title, muted summary, accent bar.
struct JournalRowView: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: ReflectTheme.spacingSM + 2) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.aiGeneratedTitle)
                        .font(ReflectTheme.serif(17, weight: .bold))
                        .foregroundStyle(ReflectTheme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Text(formattedDate)
                            .font(ReflectTheme.rounded(13))
                            .foregroundStyle(ReflectTheme.textMuted)
                        if entry.processingFailed == true {
                            Text("• failed")
                                .font(ReflectTheme.rounded(13, weight: .medium))
                                .foregroundStyle(.red.opacity(0.8))
                        } else if entry.retryPending {
                            Text("• analysing")
                                .font(ReflectTheme.rounded(13, weight: .medium))
                                .foregroundStyle(ReflectTheme.accent)
                        }
                    }
                }
                Spacer()
            }

            if !entry.oneLineSummary.isEmpty {
                Text(entry.oneLineSummary)
                    .font(ReflectTheme.rounded(14))
                    .foregroundStyle(ReflectTheme.textMuted)
                    .lineLimit(1)
            }
        }
        .padding(ReflectTheme.spacingMD)
        .background(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: ReflectTheme.cornerRadiusLG)
                    .fill(ReflectTheme.cardSurface)
                RoundedRectangle(cornerRadius: ReflectTheme.cornerRadiusLG)
                    .stroke(ReflectTheme.separator.opacity(0.5), lineWidth: 0.5)
                RoundedRectangle(cornerRadius: 2)
                    .fill(ReflectTheme.accent)
                    .frame(width: 3)
                    .padding(.vertical, 12)
                    .padding(.leading, 1)
            }
        )
        .shadow(color: ReflectTheme.softShadow.opacity(0.08), radius: 8, y: 2)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM \u{00B7} h:mm a"
        return formatter.string(from: entry.date)
    }
}
