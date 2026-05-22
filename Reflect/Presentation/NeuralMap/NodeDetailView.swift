import SwiftUI
@preconcurrency import SwiftData

/// Full-screen node detail with tab toggle, swipe-between-nodes gesture, and
/// a working "tap to respond" recording flow.
///
/// Architecture notes:
/// - Maintains its own `currentIndex` into the parent entry's `mapNodes`, so a
///   left/right swipe just bumps the index — no path manipulation, no
///   intermediate transitions.
/// - "Tap to respond…" opens `RecordingView` in `.voiceNoteFor(node)` mode;
///   the resulting transcript is appended to the node's `voiceNotes` array.
/// - Layout tightened vs. the previous version: smaller node head, denser
///   eyebrow/body spacing, footer pill anchored.
struct NodeDetailView: View {
    let initialNode: SDNode

    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    enum Tab: Hashable { case insight, transcript }

    @State private var currentIndex: Int
    @State private var tab: Tab = .insight
    @State private var isLoadingInsight = false
    @State private var showRecording = false

    init(node: SDNode) {
        self.initialNode = node
        let siblings = node.session?.mapNodes ?? []
        let idx = siblings.firstIndex(where: { $0.id == node.id }) ?? 0
        self._currentIndex = State(initialValue: idx)
    }

    private var entry: JournalEntry? { initialNode.session }
    private var siblings: [SDNode] { entry?.mapNodes ?? [initialNode] }
    private var node: SDNode {
        siblings.indices.contains(currentIndex) ? siblings[currentIndex] : initialNode
    }

    var body: some View {
        ZStack {
            ReflectTheme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                NodeRibbon(siblings: siblings, currentIndex: currentIndex) { newIdx in
                    withAnimation(ReflectTheme.springSnappy) { currentIndex = newIdx }
                    triggerLoadIfNeeded()
                }
                .padding(.bottom, 2)

                nodeHead
                    .padding(.horizontal, ReflectTheme.edge)
                    .padding(.bottom, 10)

                ScrollView {
                    Group {
                        switch tab {
                        case .insight:    insightBody
                        case .transcript: transcriptBody
                        }
                    }
                    .padding(.horizontal, ReflectTheme.edge)
                    .padding(.bottom, tab == .insight ? 8 : 28)
                }

                if tab == .insight { askBlock }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task { await loadInsight() }
        .onChange(of: currentIndex) { _, _ in
            tab = .insight
            Task { await loadInsight() }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let dx = value.translation.width
                    if dx < -60, currentIndex < siblings.count - 1 {
                        withAnimation(ReflectTheme.springSnappy) { currentIndex += 1 }
                    } else if dx > 60, currentIndex > 0 {
                        withAnimation(ReflectTheme.springSnappy) { currentIndex -= 1 }
                    }
                }
        )
        .fullScreenCover(isPresented: $showRecording) {
            RecordingView(
                mode: .voiceNoteFor(node),
                onFinished: { _ in showRecording = false },
                onClosed: { showRecording = false }
            )
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ReflectTheme.ink)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.06)))
            }
            Spacer()
            VStack(spacing: 2) {
                Text("MAP · THIS ENTRY")
                    .font(ReflectTheme.rounded(10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(ReflectTheme.inkFaint)
                Text("\(currentIndex + 1) of \(siblings.count)")
                    .font(ReflectTheme.rounded(11.5, weight: .medium))
                    .foregroundStyle(ReflectTheme.inkSoft)
            }
            Spacer()
            tabToggle
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var tabToggle: some View {
        Button {
            withAnimation(ReflectTheme.springSnappy) {
                tab = (tab == .insight) ? .transcript : .insight
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab == .transcript ? "lightbulb" : "text.alignleft")
                    .font(.system(size: 11, weight: .bold))
                Text(tab == .transcript ? "Insight" : "Transcript")
                    .font(ReflectTheme.rounded(12, weight: .semibold))
            }
            .foregroundStyle(tab == .transcript ? Color.white : ReflectTheme.blue500)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(Capsule().fill(tab == .transcript ? ReflectTheme.blue700 : ReflectTheme.blue50))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Node head (compact)

    private var nodeHead: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Circle()
                    .fill(ReflectTheme.color(for: node.emotion))
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.label.prefix(1).uppercased() + node.label.dropFirst())
                        .font(.system(size: 22, weight: .medium, design: .serif))
                        .foregroundStyle(ReflectTheme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        miniPill(label: node.category.label,
                                 color: ReflectTheme.blue500,
                                 bg: ReflectTheme.blue50)
                        miniPill(label: node.emotion.label,
                                 color: node.emotion.prefersDarkText ? ReflectTheme.ink : .white,
                                 bg: ReflectTheme.color(for: node.emotion).opacity(0.20))
                    }
                }
                Spacer()
            }
            if !voiceNotes.isEmpty {
                Text("\(voiceNotes.count) voice note\(voiceNotes.count == 1 ? "" : "s") · \(metadataLine)")
                    .font(ReflectTheme.rounded(11.5, weight: .medium))
                    .foregroundStyle(ReflectTheme.inkFaint)
            } else {
                Text(metadataLine)
                    .font(ReflectTheme.rounded(11.5, weight: .medium))
                    .foregroundStyle(ReflectTheme.inkFaint)
            }
        }
    }

    private func miniPill(label: String, color: Color, bg: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(ReflectTheme.rounded(10.5, weight: .semibold))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .foregroundStyle(color)
        .background(Capsule().fill(bg))
    }

    private var metadataLine: String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        let date = entry?.date ?? Date()
        return "First mentioned \(f.string(from: date))"
    }

    // MARK: - Bodies

    @ViewBuilder
    private var insightBody: some View {
        if isLoadingInsight && (node.expandedContent ?? "").isEmpty {
            SkeletonReflection()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("AI INSIGHT").eyebrowStyle(color: ReflectTheme.mustard500)

                Text(node.expandedContent ?? fallbackInsight)
                    .font(ReflectTheme.serif(15.5))
                    .foregroundStyle(ReflectTheme.ink)
                    .lineSpacing(4)

                if !connectedNodes.isEmpty {
                    Text("Connects to \(connectedListString).")
                        .font(ReflectTheme.serif(14))
                        .foregroundStyle(ReflectTheme.inkSoft)
                        .lineSpacing(3)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("CONNECTED NODES").eyebrowStyle()
                        FlowLayout(spacing: 8) {
                            ForEach(connectedNodes, id: \.id) { connected in
                                ConnectedNodeChip(node: connected)
                            }
                        }
                    }
                    .padding(.top, 2)
                }

                if !voiceNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR RESPONSES").eyebrowStyle(color: ReflectTheme.primary)
                        ForEach(Array(voiceNotes.enumerated()), id: \.offset) { _, note in
                            Text(note)
                                .font(ReflectTheme.serif(14))
                                .foregroundStyle(ReflectTheme.ink)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(ReflectTheme.mustard50)
                                )
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private var transcriptBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Capsule().fill(ReflectTheme.mustard500).frame(width: 22, height: 3)
                Text("underlined = used to build your insight")
                    .font(ReflectTheme.rounded(11, weight: .medium))
                    .foregroundStyle(ReflectTheme.inkFaint)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Rectangle().fill(ReflectTheme.separator).frame(height: 0.5)
                    Text(dateStamp(entry?.date ?? Date()))
                        .font(ReflectTheme.mono(10.5))
                        .foregroundStyle(ReflectTheme.inkFaint)
                        .tracking(0.8)
                    Rectangle().fill(ReflectTheme.separator).frame(height: 0.5)
                }

                Text(transcriptText)
                    .font(ReflectTheme.serif(16))
                    .foregroundStyle(ReflectTheme.ink)
                    .lineSpacing(7)
            }
        }
    }

    // MARK: - Ask block (insight tab only)

    private var askBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(ReflectTheme.color(for: node.emotion))
                    .frame(width: 22, height: 22)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("REFLECT ASKS")
                        .eyebrowStyle(color: ReflectTheme.inkFaint)
                    askText
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(ReflectTheme.surface2)
                )
                Spacer(minLength: 0)
            }

            Button { showRecording = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(voiceNotes.isEmpty ? "Tap to respond" : "Add another response")
                        .font(ReflectTheme.rounded(13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(
                    UnevenRoundedRectangle(
                        cornerRadii: .init(topLeading: 14, bottomLeading: 14,
                                           bottomTrailing: 14, topTrailing: 4),
                        style: .continuous
                    )
                    .fill(ReflectTheme.primary)
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 18)
        .overlay(Rectangle().fill(ReflectTheme.separator).frame(height: 0.5),
                 alignment: .top)
    }

    /// The contextual Socratic question, fed straight from the deep-dive
    /// response. Shows a soft placeholder while still loading or if the call
    /// failed; never falls back to the old generic template.
    @ViewBuilder
    private var askText: some View {
        if let question = node.expandedQuestion, !question.isEmpty {
            Text(question)
                .font(ReflectTheme.serif(14.5))
                .foregroundStyle(ReflectTheme.ink)
                .lineSpacing(3)
        } else if isLoadingInsight {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                    .tint(ReflectTheme.inkFaint)
                Text("Thinking of something to ask…")
                    .font(ReflectTheme.serif(14))
                    .italic()
                    .foregroundStyle(ReflectTheme.inkSoft)
            }
        } else {
            Text("Reflect needs your transcript to craft a question. Try again once analysis finishes.")
                .font(ReflectTheme.serif(14))
                .italic()
                .foregroundStyle(ReflectTheme.inkSoft)
                .lineSpacing(3)
        }
    }

    // MARK: - Insight loading + helpers

    private var fallbackInsight: String {
        "Tap to ask Reflect to expand on this theme — we'll quote your own words and offer a gentle question."
    }

    private var transcriptText: String {
        guard let entry else { return "No transcript available." }
        return entry.polishedTranscript.isEmpty ? entry.rawTranscript : entry.polishedTranscript
    }

    private var connectedNodes: [SDNode] {
        guard let entry else { return [] }
        let id = node.id
        let connectedIds = entry.mapLinks
            .filter { $0.source == id || $0.target == id }
            .map { $0.source == id ? $0.target : $0.source }
        return entry.mapNodes.filter { connectedIds.contains($0.id) }
    }

    private var connectedListString: String {
        let labels = connectedNodes.prefix(3).map { $0.label }
        if labels.isEmpty { return "no other nodes yet" }
        if labels.count == 1 { return labels[0] }
        return labels.dropLast().joined(separator: ", ") + " and " + (labels.last ?? "")
    }

    private var voiceNotes: [String] { node.voiceNotes }

    private func dateStamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE · MMM d · h:mm a"
        return f.string(from: date).uppercased()
    }

    private func triggerLoadIfNeeded() {
        Task { await loadInsight() }
    }

    private func loadInsight() async {
        // Skip if we already have both halves of the deep dive.
        guard (node.expandedContent ?? "").isEmpty
            || (node.expandedQuestion ?? "").isEmpty
        else { return }

        isLoadingInsight = true
        let transcript = transcriptText
        let captured = node // capture before any swipes
        do {
            let dive = try await services.deepDiveService.expand(
                themeLabel: captured.label, transcript: transcript
            )
            let repo = services.makeRepository(context: modelContext)
            try? repo.setDeepDive(dive, for: captured)
        } catch {
            print("⚠️ Deep dive failed: \(error)")
        }
        isLoadingInsight = false
    }
}

// MARK: - Subviews

private struct NodeRibbon: View {
    let siblings: [SDNode]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 14) {
            Spacer(minLength: 0)
            ForEach(Array(siblings.enumerated()), id: \.element.id) { i, n in
                let offset = i - currentIndex
                let isCurrent = offset == 0
                let isNeighbor = abs(offset) == 1
                let size: CGFloat = isCurrent ? 22 : isNeighbor ? 14 : 6
                Button { onSelect(i) } label: {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(ReflectTheme.color(for: n.emotion))
                            .frame(width: size, height: size)
                            .overlay(
                                Circle()
                                    .stroke(ReflectTheme.color(for: n.emotion).opacity(0.22),
                                            lineWidth: isCurrent ? 4 : 0)
                            )
                        if isCurrent {
                            Text("HERE")
                                .font(ReflectTheme.rounded(9, weight: .bold))
                                .foregroundStyle(ReflectTheme.inkSoft)
                                .tracking(0.7)
                        }
                    }
                    .opacity(abs(offset) > 2 ? 0.3 : 1)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ReflectTheme.edge)
        .padding(.top, 8)
    }
}

private struct ConnectedNodeChip: View {
    let node: SDNode
    var body: some View {
        NavigationLink(value: node) {
            HStack(spacing: 8) {
                Circle().fill(ReflectTheme.color(for: node.emotion)).frame(width: 8, height: 8)
                Text(node.label)
                    .font(ReflectTheme.rounded(12, weight: .medium))
                    .foregroundStyle(ReflectTheme.ink)
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

private struct SkeletonReflection: View {
    @State private var shimmer = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THINKING…")
                .eyebrowStyle(color: ReflectTheme.mustard500)
                .padding(.bottom, 4)
            shimmerBar(width: .infinity)
            shimmerBar(width: 280)
            shimmerBar(width: 220)
            shimmerBar(width: 0).frame(height: 14)
            shimmerBar(width: 200)
            shimmerBar(width: 240)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                shimmer.toggle()
            }
        }
    }

    private func shimmerBar(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [ReflectTheme.surface3, ReflectTheme.surface, ReflectTheme.surface3],
                    startPoint: shimmer ? .leading : .trailing,
                    endPoint: shimmer ? .trailing : .leading
                )
            )
            .frame(maxWidth: width == .infinity ? .infinity : width)
            .frame(height: 12)
    }
}
