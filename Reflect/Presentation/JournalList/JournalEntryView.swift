import SwiftUI
@preconcurrency import SwiftData

/// Full transcript view for a single journal entry.
///
/// Per design: back chevron + 3-dot menu top bar; mono date + serif title +
/// emotion pills; blue-700 metadata strip with "VOICE RECORDING", duration,
/// "TRANSCRIBED" badge and a decorative waveform; "NODES GENERATED" chips
/// row; "FULL TRANSCRIPT" with mono timestamps + serif lines (some
/// mustard-highlighted to indicate which fed the insight); footer note.
struct JournalEntryView: View {
    let entry: JournalEntry

    @Environment(\.dismiss) private var dismiss
    @State private var showMapRoute = false

    var body: some View {
        ZStack {
            ReflectTheme.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                    titleBlock
                        .padding(.horizontal, ReflectTheme.edge)
                        .padding(.bottom, 14)
                    metadataStrip
                        .padding(.horizontal, ReflectTheme.edge)
                        .padding(.bottom, 18)
                    nodesSection
                        .padding(.horizontal, ReflectTheme.edge)
                        .padding(.bottom, 16)
                    transcriptSection
                        .padding(.horizontal, ReflectTheme.edge)
                        .padding(.bottom, 28)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showMapRoute) {
            NeuralMapView(entry: entry)
        }
    }

    // MARK: - Sub-views

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ReflectTheme.ink)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.06)))
            }
            Spacer()
            Button { showMapRoute = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain")
                        .font(.system(size: 11, weight: .bold))
                    Text("View map")
                        .font(ReflectTheme.rounded(12, weight: .semibold))
                }
                .foregroundStyle(ReflectTheme.blue500)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Capsule().fill(ReflectTheme.blue50))
            }
            .buttonStyle(.plain)
            Menu {
                Button("Share entry", systemImage: "square.and.arrow.up") { share() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ReflectTheme.ink)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.06)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dateLine)
                .font(ReflectTheme.mono(11))
                .foregroundStyle(ReflectTheme.inkFaint)
                .tracking(0.8)
            Text(entry.aiGeneratedTitle)
                .font(.system(size: 28, weight: .medium, design: .serif))
                .foregroundStyle(ReflectTheme.ink)
                .lineLimit(3)

            if !entryEmotions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(entryEmotions, id: \.self) { e in EmotionPill(emotion: e) }
                }
            }
        }
    }

    private var metadataStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("VOICE RECORDING")
                        .eyebrowStyle(color: ReflectTheme.mustard300)
                    Text("\(durationLabel) · \(dateLine)")
                        .font(ReflectTheme.mono(13))
                        .foregroundStyle(.white)
                        .tracking(0.4)
                }
                Spacer()
                Text("TRANSCRIBED")
                    .font(ReflectTheme.rounded(10.5, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(ReflectTheme.mustard300)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(ReflectTheme.mustard300.opacity(0.15)))
            }

            // Decorative waveform — static bars, intentionally not interactive.
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<25, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 5, height: barHeight(for: i))
                }
            }
            .frame(height: 24)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ReflectTheme.blue700)
        )
    }

    private var nodesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NODES GENERATED").eyebrowStyle()
            if entry.mapNodes.isEmpty {
                Text("Processing in progress — your nodes will appear here once analysis completes.")
                    .font(ReflectTheme.rounded(13))
                    .foregroundStyle(ReflectTheme.inkSoft)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(entry.mapNodes, id: \.id) { node in
                        NodeChipLink(node: node, entry: entry)
                    }
                }
            }
        }
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FULL TRANSCRIPT").eyebrowStyle(color: ReflectTheme.blue500)
            Text(transcriptText)
                .font(ReflectTheme.serif(16))
                .foregroundStyle(ReflectTheme.ink)
                .lineSpacing(6)
            if !entry.mapNodes.isEmpty {
                HStack(spacing: 10) {
                    Circle()
                        .fill(ReflectTheme.mustard300)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(ReflectTheme.mustard700)
                        )
                    Text("\(entry.mapNodes.count) node\(entry.mapNodes.count == 1 ? "" : "s") were extracted from this entry.")
                        .font(ReflectTheme.rounded(12, weight: .medium))
                        .foregroundStyle(ReflectTheme.mustard700)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(ReflectTheme.mustard50)
                )
                .padding(.top, 12)
            }
        }
    }

    // MARK: - Helpers

    private var dateLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEE · MMM d · h:mm a"
        return f.string(from: entry.date).uppercased()
    }

    private var transcriptText: String {
        let t = entry.polishedTranscript.isEmpty ? entry.rawTranscript : entry.polishedTranscript
        return t.isEmpty ? "No transcript captured for this entry." : t
    }

    private var durationLabel: String {
        // No real duration field; estimate from word count (~150 wpm).
        let words = entry.rawTranscript.split(separator: " ").count
        let seconds = max(8, (words * 60) / 150)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var entryEmotions: [Emotion] {
        var seen = Set<String>()
        return entry.mapNodes.compactMap { node in
            let key = node.emotionKey
            guard seen.insert(key).inserted else { return nil }
            return node.emotion
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        // Deterministic-feeling sawtooth so it looks like a waveform, not noise.
        let heights: [CGFloat] = [8, 14, 20, 10, 18, 24, 12, 16, 8, 22, 16, 10, 20, 14, 8,
                                  18, 12, 24, 16, 10, 18, 8, 14, 20, 16]
        return heights[index % heights.count]
    }

    private func share() {
        let body = entry.polishedTranscript.isEmpty ? entry.rawTranscript : entry.polishedTranscript
        let text = """
        \(entry.aiGeneratedTitle)

        \(body)

        — Reflected on \(dateLine)
        """
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
           let root = window.rootViewController {
            root.present(activityVC, animated: true)
        }
    }
}

// MARK: - Small reusable bits

private struct EmotionPill: View {
    let emotion: Emotion
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(ReflectTheme.color(for: emotion)).frame(width: 8, height: 8)
            Text(emotion.label)
                .font(ReflectTheme.rounded(11.5, weight: .semibold))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .foregroundStyle(emotion.prefersDarkText ? ReflectTheme.ink : .white)
        .background(Capsule().fill(ReflectTheme.color(for: emotion).opacity(0.20)))
    }
}

private struct NodeChipLink: View {
    let node: SDNode
    let entry: JournalEntry
    var body: some View {
        NavigationLink(value: node) {
            HStack(spacing: 8) {
                Circle().fill(ReflectTheme.color(for: node.emotion)).frame(width: 10, height: 10)
                Text(node.label)
                    .font(ReflectTheme.rounded(12.5, weight: .medium))
                    .foregroundStyle(ReflectTheme.ink)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(ReflectTheme.inkFaint)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
                Capsule().fill(Color.white)
                    .overlay(Capsule().stroke(ReflectTheme.separator, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}
