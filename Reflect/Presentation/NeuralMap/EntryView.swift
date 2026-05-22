import SwiftUI
@preconcurrency import SwiftData
import UIKit

/// Unified screen for a single journal entry.
///
/// Per the latest Reflect design, the map view and the transcript view live
/// on the same surface — a top-bar toggle pill switches between them.
///
/// Architecture:
/// - Both modes share the `JournalEntry`, the entry's `NeuralMapViewModel`
///   (which handles AI processing + layout), and the navigation stack.
/// - Map mode pushes `SDNode` values onto the path → NodeDetailView.
/// - Transcript mode pushes those same SDNode values via the "nodes
///   generated" chips.
/// - The bottom-centre PulsingRing is shown only in map mode and starts a
///   recording **appended to this entry** (so additional reflections layer on).
struct EntryView: View {
    let entry: JournalEntry
    /// Optional override for the initial mode (defaults to map).
    var initialMode: Mode = .map

    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    enum Mode: Hashable { case map, transcript }

    @State private var mode: Mode = .map
    @State private var viewModel: NeuralMapViewModel?
    @State private var showRecording = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                ReflectTheme.canvas.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    if let vm = viewModel {
                        switch mode {
                        case .map:
                            MapSection(entry: entry, viewModel: vm)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .transcript:
                            TranscriptSection(entry: entry)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        ProgressView()
                            .tint(ReflectTheme.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                if mode == .map {
                    RecordRingFAB(label: "ADD REFLECTION") {
                        showRecording = true
                    }
                    .padding(.bottom, 24)
                }
            }
            .task(id: entry.id) {
                if viewModel == nil {
                    let repo = services.makeRepository(context: modelContext)
                    viewModel = NeuralMapViewModel(
                        entry: entry,
                        repository: repo,
                        entryProcessor: services.entryProcessor,
                        deepDiveService: services.deepDiveService
                    )
                    mode = initialMode
                }
                await viewModel?.start(canvasSize: proxy.size)
            }
            .onChange(of: proxy.size) { _, newSize in
                viewModel?.updateCanvasSize(newSize)
            }
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $showRecording) {
            RecordingView(
                mode: .appendingTo(entry),
                onFinished: { _ in showRecording = false },
                onClosed: { showRecording = false }
            )
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ReflectTheme.ink)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.06)))
            }
            Spacer()
            modeToggle
            Spacer()
            Menu {
                Button("Share entry", systemImage: "square.and.arrow.up") { shareEntry() }
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

    private var modeToggle: some View {
        HStack(spacing: 2) {
            toggleSegment(label: "Map", value: .map, icon: "circle.grid.cross")
            toggleSegment(label: "Transcript", value: .transcript, icon: "text.alignleft")
        }
        .padding(3)
        .background(
            Capsule().fill(ReflectTheme.surface2)
        )
    }

    private func toggleSegment(label: String, value: Mode, icon: String) -> some View {
        Button {
            withAnimation(ReflectTheme.springSnappy) { mode = value }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(ReflectTheme.rounded(12, weight: .semibold))
            }
            .foregroundStyle(mode == value ? Color.white : ReflectTheme.blue500)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(
                Capsule().fill(mode == value ? ReflectTheme.blue700 : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func shareEntry() {
        let body = entry.polishedTranscript.isEmpty ? entry.rawTranscript : entry.polishedTranscript
        let f = DateFormatter(); f.dateStyle = .medium
        let text = "\(entry.aiGeneratedTitle)\n\n\(body)\n\n— Reflected on \(f.string(from: entry.date))"
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
           let root = window.rootViewController {
            root.present(vc, animated: true)
        }
    }
}

// MARK: - Map section

private struct MapSection: View {
    let entry: JournalEntry
    let viewModel: NeuralMapViewModel
    @State private var activeFilter: NodeCategory? = nil
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            titleBlock
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            filterStrip
                .padding(.bottom, 4)
            ZStack {
                paperDotField
                    .ignoresSafeArea()

                switch viewModel.state {
                case .processing, .idle:
                    processingOverlay
                case .failed(let m):
                    failureOverlay(message: m)
                case .ready:
                    graphLayer
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { withAnimation(.easeOut(duration: 0.3)) { appeared = true } }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Neural map · \(viewModel.nodes.count) node\(viewModel.nodes.count == 1 ? "" : "s")")
                .eyebrowStyle(color: ReflectTheme.mustard500)
            Text(entry.aiGeneratedTitle)
                .font(.system(size: 24, weight: .medium, design: .serif))
                .foregroundStyle(ReflectTheme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filterStrip: some View {
        let cats = viewModel.categories
        return Group {
            if cats.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterPill(label: "All", isActive: activeFilter == nil) {
                            activeFilter = nil
                        }
                        ForEach(cats, id: \.storageKey) { category in
                            FilterPill(label: category.label, isActive: activeFilter == category) {
                                activeFilter = (activeFilter == category) ? nil : category
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var paperDotField: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 18
            ctx.opacity = 0.45
            for x in stride(from: 0, through: size.width, by: spacing) {
                for y in stride(from: 0, through: size.height, by: spacing) {
                    let rect = CGRect(x: x - 0.5, y: y - 0.5, width: 1, height: 1)
                    ctx.fill(Path(ellipseIn: rect), with: .color(ReflectTheme.ink.opacity(0.06)))
                }
            }
        }
    }

    @ViewBuilder
    private var graphLayer: some View {
        let positioned = viewModel.nodes
        let edges = viewModel.edges
        ZStack {
            // Edges (canvas-drawn for performance)
            Canvas { ctx, _ in
                for (i, edge) in edges.enumerated() {
                    guard let a = positioned.first(where: { $0.id == edge.source }),
                          let b = positioned.first(where: { $0.id == edge.target }) else { continue }
                    let mx = (a.position.x + b.position.x) / 2 + (i.isMultiple(of: 2) ? -16 : 16)
                    let my = (a.position.y + b.position.y) / 2 + (i.isMultiple(of: 2) ? 16 : -12)
                    var p = Path()
                    p.move(to: a.position)
                    p.addQuadCurve(to: b.position, control: CGPoint(x: mx, y: my))
                    let dim = isDimmed(a) || isDimmed(b)
                    ctx.stroke(p,
                               with: .color(dim
                                            ? ReflectTheme.inkFaint.opacity(0.15)
                                            : ReflectTheme.inkSoft.opacity(0.26)),
                               style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                }
            }

            // Nodes
            ForEach(positioned) { positionedNode in
                if let sd = entry.mapNodes.first(where: { $0.id == positionedNode.id }) {
                    NavigationLink(value: sd) {
                        MapNodeView(node: positionedNode, isDimmed: isDimmed(positionedNode))
                    }
                    .buttonStyle(.plain)
                    .position(positionedNode.position)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: appeared)
    }

    private var processingOverlay: some View {
        VStack(spacing: 14) {
            ProgressView().tint(ReflectTheme.primary).scaleEffect(1.2)
            Text("Processing neural map…")
                .font(ReflectTheme.rounded(15, weight: .medium))
                .foregroundStyle(ReflectTheme.inkSoft)
            Text("This usually takes 5–20 seconds.")
                .font(ReflectTheme.rounded(12))
                .foregroundStyle(ReflectTheme.inkFaint)
        }
    }

    private func failureOverlay(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(ReflectTheme.primary)
            Text("Couldn't analyse this reflection")
                .font(ReflectTheme.serif(17, weight: .semibold))
                .foregroundStyle(ReflectTheme.ink)
            Text(message)
                .font(ReflectTheme.rounded(13))
                .foregroundStyle(ReflectTheme.inkSoft)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await viewModel.retry() } }
                .buttonStyle(.borderedProminent)
                .tint(ReflectTheme.primary)
        }
        .padding(20)
    }

    private func isDimmed(_ node: PositionedNode) -> Bool {
        guard let activeFilter else { return false }
        return node.category != activeFilter
    }
}

// MARK: - Transcript section (no voice recording card)

private struct TranscriptSection: View {
    let entry: JournalEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                titleBlock
                    .padding(.horizontal, ReflectTheme.edge)
                    .padding(.top, 4)
                nodesGenerated
                    .padding(.horizontal, ReflectTheme.edge)
                transcriptBody
                    .padding(.horizontal, ReflectTheme.edge)
                    .padding(.bottom, 28)
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dateLine)
                .font(ReflectTheme.mono(11))
                .foregroundStyle(ReflectTheme.inkFaint)
                .tracking(0.8)
            Text(entry.aiGeneratedTitle)
                .font(.system(size: 26, weight: .medium, design: .serif))
                .foregroundStyle(ReflectTheme.ink)
                .lineSpacing(2)
            if !entry.oneLineSummary.isEmpty {
                Text(entry.oneLineSummary)
                    .font(ReflectTheme.serif(15))
                    .italic()
                    .foregroundStyle(ReflectTheme.inkSoft)
            }
            if !entryEmotions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(entryEmotions, id: \.self) { e in EmotionPill(emotion: e) }
                }
                .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private var nodesGenerated: some View {
        if !entry.mapNodes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("NODES GENERATED").eyebrowStyle()
                FlowLayout(spacing: 8) {
                    ForEach(entry.mapNodes, id: \.id) { node in
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
            }
        }
    }

    private var transcriptBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRANSCRIPT").eyebrowStyle(color: ReflectTheme.blue500)
            Text(transcriptText)
                .font(ReflectTheme.serif(16))
                .foregroundStyle(ReflectTheme.ink)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var dateLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEE · MMM d · h:mm a"
        return f.string(from: entry.date).uppercased()
    }

    private var transcriptText: String {
        let t = entry.polishedTranscript.isEmpty ? entry.rawTranscript : entry.polishedTranscript
        return t.isEmpty ? "No transcript captured for this entry." : t
    }

    private var entryEmotions: [Emotion] {
        var seen = Set<String>()
        return entry.mapNodes.compactMap { node in
            let key = node.emotionKey
            guard seen.insert(key).inserted else { return nil }
            return node.emotion
        }
    }
}

// MARK: - Map node bubble

private struct MapNodeView: View {
    let node: PositionedNode
    let isDimmed: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(ReflectTheme.color(for: node.emotion))
                .frame(width: diameter, height: diameter)
                .overlay(Circle().stroke(Color.black.opacity(0.04), lineWidth: 0.5))
            // Subtle gloss top-left
            Ellipse()
                .fill(Color.white.opacity(0.22))
                .frame(width: diameter * 0.36, height: diameter * 0.18)
                .offset(x: -diameter * 0.18, y: -diameter * 0.20)
            if diameter >= 54 {
                Text(node.label)
                    .font(.system(size: min(13, diameter * 0.22), weight: .medium, design: .serif))
                    .foregroundStyle(ReflectTheme.textColor(for: node.emotion))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 6)
                    .frame(width: diameter, height: diameter)
            }
        }
        .opacity(isDimmed ? 0.22 : 1)
        .animation(ReflectTheme.springSnappy, value: isDimmed)
    }

    private var diameter: CGFloat {
        ReflectTheme.nodeDiameter(prominence: node.prominence)
    }
}

// MARK: - Shared widgets

/// Bottom-centre record FAB. Caller passes label so the wording reflects
/// context (NEW REFLECTION on the list, ADD REFLECTION inside an entry).
struct RecordRingFAB: View {
    let label: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            PulsingRing(mode: .resting, size: 76, onTap: action)
            Text(label)
                .font(ReflectTheme.rounded(10, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(ReflectTheme.inkSoft)
        }
    }
}

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
