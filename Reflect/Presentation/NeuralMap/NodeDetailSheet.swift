import SwiftUI
@preconcurrency import SwiftData

/// Bottom sheet shown when a node is tapped. Lazily fetches an expanded
/// reflection from the deep-dive service and lets the user attach a voice
/// note attached to this specific theme.
struct NodeDetailSheet: View {
    let node: PositionedNode
    let entry: JournalEntry
    let viewModel: NeuralMapViewModel

    @State private var isLoading = false
    @State private var showRecording = false

    private var sdNode: SDNode? {
        entry.mapNodes.first(where: { $0.id == node.id })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReflectTheme.spacingLG) {
                header
                Divider().background(ReflectTheme.separator)

                if let content = sdNode?.expandedContent {
                    Text(content)
                        .font(ReflectTheme.serif(16))
                        .foregroundStyle(ReflectTheme.textPrimary.opacity(0.8))
                        .lineSpacing(5)
                } else if isLoading {
                    ProgressView()
                        .tint(ReflectTheme.accent)
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text("Tap an icebreaker question to dive deeper into this theme.")
                        .font(ReflectTheme.rounded(14))
                        .foregroundStyle(ReflectTheme.textMuted)
                }

                if let sd = sdNode, !sd.voiceNotes.isEmpty {
                    voiceNotes(for: sd)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, ReflectTheme.spacingLG)
            .padding(.top, ReflectTheme.spacingMD)
        }
        .task { await loadExpanded() }
        .overlay(alignment: .bottom) { recordCTA }
        .fullScreenCover(isPresented: $showRecording) {
            if let sd = sdNode {
                RecordingView(
                    mode: .voiceNoteFor(sd),
                    onFinished: { _ in showRecording = false },
                    onClosed: { showRecording = false }
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(ReflectTheme.color(for: node.emotion))
                .frame(width: 10, height: 10)
            Text(node.label)
                .font(ReflectTheme.serif(22, weight: .semibold))
                .foregroundStyle(ReflectTheme.textPrimary)
            Spacer()
        }
    }

    private func voiceNotes(for sd: SDNode) -> some View {
        VStack(alignment: .leading, spacing: ReflectTheme.spacingSM) {
            Text("Voice notes")
                .font(ReflectTheme.rounded(11, weight: .bold))
                .foregroundStyle(ReflectTheme.textMuted)
                .textCase(.uppercase)
                .tracking(1.0)
            ForEach(sd.voiceNotes, id: \.self) { note in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(ReflectTheme.color(for: node.emotion))
                        .font(.system(size: 14))
                        .padding(.top, 2)
                    Text(note)
                        .font(ReflectTheme.serif(15))
                        .foregroundStyle(ReflectTheme.textPrimary)
                        .lineSpacing(4)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.top, ReflectTheme.spacingMD)
    }

    private var recordCTA: some View {
        Button { showRecording = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                Text("Add voice note")
            }
            .font(ReflectTheme.rounded(16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(ReflectTheme.color(for: node.emotion))
                    .shadow(color: ReflectTheme.color(for: node.emotion).opacity(0.4), radius: 8, y: 4)
            )
            .padding(.horizontal, ReflectTheme.spacingLG)
            .padding(.bottom, ReflectTheme.spacingLG)
        }
    }

    private func loadExpanded() async {
        guard sdNode?.expandedContent == nil else { return }
        isLoading = true
        await viewModel.loadExpandedContent(for: node)
        isLoading = false
    }
}
