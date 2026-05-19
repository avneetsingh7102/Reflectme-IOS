import SwiftUI

/// Single row on the journal list — redesigned per Reflect Mobile.
///
/// White card with: mono date + duration (top row), serif title, serif
/// preview, and an emotion-dot cluster on the right.
struct JournalRowView: View {
    let entry: JournalEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(dateLabel)
                        .font(ReflectTheme.mono(10.5))
                        .tracking(0.6)
                        .foregroundStyle(ReflectTheme.inkFaint)
                    Text(durationLabel)
                        .font(ReflectTheme.mono(10))
                        .foregroundStyle(ReflectTheme.inkFaint.opacity(0.7))
                    if entry.processingFailed == true {
                        Text("• failed")
                            .font(ReflectTheme.rounded(11, weight: .medium))
                            .foregroundStyle(.red.opacity(0.8))
                    } else if entry.retryPending {
                        Text("• analysing")
                            .font(ReflectTheme.rounded(11, weight: .medium))
                            .foregroundStyle(ReflectTheme.primary)
                    }
                }

                Text(entry.aiGeneratedTitle)
                    .font(ReflectTheme.serif(17, weight: .medium))
                    .foregroundStyle(ReflectTheme.ink)
                    .lineSpacing(2)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !preview.isEmpty {
                    Text(preview)
                        .font(ReflectTheme.serif(13.5))
                        .foregroundStyle(ReflectTheme.inkSoft)
                        .lineSpacing(2)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 0)

            if !emotions.isEmpty {
                HStack(spacing: 3) {
                    ForEach(emotions, id: \.self) { e in
                        Circle()
                            .fill(ReflectTheme.color(for: e))
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.5))
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: ReflectTheme.softShadow, radius: 6, y: 2)
        )
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE · MMM d · h:mm a"
        return f.string(from: entry.date).uppercased()
    }

    private var durationLabel: String {
        let words = entry.rawTranscript.split(separator: " ").count
        let seconds = max(8, (words * 60) / 150)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var preview: String {
        if !entry.oneLineSummary.isEmpty { return entry.oneLineSummary }
        return entry.rawTranscript
            .replacingOccurrences(of: "\n", with: " ")
    }

    private var emotions: [Emotion] {
        var seen = Set<String>()
        return entry.mapNodes.prefix(3).compactMap { node in
            let key = node.emotionKey
            guard seen.insert(key).inserted else { return nil }
            return node.emotion
        }
    }
}
