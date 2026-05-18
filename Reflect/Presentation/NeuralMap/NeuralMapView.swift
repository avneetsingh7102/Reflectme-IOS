import SwiftUI
@preconcurrency import SwiftData
import UIKit

/// The neural map for one journal entry. Renders the theme graph the LLM
/// extracted from the transcript, supports drag + zoom + filter, and switches
/// between map and transcript views.
struct NeuralMapView: View {
    let entry: JournalEntry

    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: NeuralMapViewModel?

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let viewModel {
                    LoadedNeuralMapView(viewModel: viewModel, entry: entry, canvasSize: proxy.size)
                } else {
                    ZStack {
                        ReflectTheme.canvas.ignoresSafeArea()
                        ProgressView()
                            .tint(ReflectTheme.accent)
                    }
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
                }
                await viewModel?.start(canvasSize: proxy.size)
            }
            .onChange(of: proxy.size) { _, newSize in
                viewModel?.updateCanvasSize(newSize)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

/// Active map UI rendered once the ViewModel exists. Splitting this out keeps
/// the body small and ensures `@Observable` tracking sees a non-optional
/// reference (which is more reliable than `viewModel?.state`).
private struct LoadedNeuralMapView: View {
    let viewModel: NeuralMapViewModel
    let entry: JournalEntry
    let canvasSize: CGSize

    @Environment(\.dismiss) private var dismiss

    @State private var selectedNodeId: String?
    @State private var showNodeDetail = false
    @State private var selectedEdge: SDLink?
    @State private var showEdgeExplanation = false
    @State private var showTranscript = false
    @State private var showRecording = false
    @State private var viewMode: ViewMode = .map
    @State private var activeFilter: NodeCategory?
    @State private var appeared = false

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    enum ViewMode: Hashable { case map, transcript }

    var body: some View {
        ZStack {
            ReflectTheme.canvas.ignoresSafeArea()
            gridBackground
            centerGlow

            if viewMode == .map {
                mapCanvas
            } else {
                transcriptArea
            }

            overlayChrome

            if viewModel.showUpdateToast {
                updateToast
            }
        }
        .task {
            withAnimation(.easeOut(duration: 0.3)) { appeared = true }
        }
        .onChange(of: entry.retryPending) { _, isPending in
            if isPending { Task { await viewModel.retry() } }
        }
        .onChange(of: viewModel.showUpdateToast) { _, show in
            guard show else { return }
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                viewModel.showUpdateToast = false
            }
        }
        .sheet(isPresented: $showNodeDetail) { nodeDetailSheet }
        .sheet(isPresented: $showTranscript) { TranscriptSheet(entry: entry) }
        .sheet(isPresented: $showEdgeExplanation) { edgeExplanationSheet }
        .fullScreenCover(isPresented: $showRecording) {
            RecordingView(
                mode: .appendingTo(entry),
                onFinished: { _ in showRecording = false },
                onClosed: { showRecording = false }
            )
        }
    }

    // MARK: - Map layers

    private var gridBackground: some View {
        Canvas { ctx, size in
            let grid: CGFloat = 40
            ctx.stroke(
                Path { p in
                    for x in stride(from: 0, through: size.width, by: grid) {
                        p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: 0, through: size.height, by: grid) {
                        p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                    }
                },
                with: .color(ReflectTheme.separator.opacity(0.1)),
                lineWidth: 0.5
            )
        }
        .ignoresSafeArea()
    }

    private var centerGlow: some View {
        RadialGradient(
            colors: [ReflectTheme.accent.opacity(0.02), .clear],
            center: .center, startRadius: 100, endRadius: 400
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var mapCanvas: some View {
        ZStack {
            switch viewModel.state {
            case .processing, .idle:
                processingOverlay
            case .failed(let message):
                failureOverlay(message: message)
            case .ready:
                graphLayer
            }
        }
        .scaleEffect(scale)
        .offset(offset)
        .gesture(
            DragGesture()
                .onChanged { val in
                    offset = CGSize(
                        width: lastOffset.width + val.translation.width,
                        height: lastOffset.height + val.translation.height
                    )
                }
                .onEnded { _ in lastOffset = offset }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { val in scale = min(max(lastScale * val.magnification, 0.5), 3.0) }
                .onEnded { _ in lastScale = scale }
        )
    }

    @ViewBuilder
    private var graphLayer: some View {
        let filtered = viewModel.filter(by: activeFilter)
        ZStack {
            ForEach(filtered.edges) { edge in
                if let source = filtered.nodes.first(where: { $0.id == edge.source }),
                   let target = filtered.nodes.first(where: { $0.id == edge.target }) {
                    edgeShape(source: source.position, target: target.position, value: edge.value) {
                        selectedEdge = edge
                        showEdgeExplanation = true
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeIn(duration: 0.4).delay(0.5), value: appeared)
                }
            }

            ForEach(filtered.nodes) { node in
                ThoughtNodeView(node: node, isSelected: selectedNodeId == node.id) {
                    selectedNodeId = node.id
                    showNodeDetail = true
                }
                .position(node.position)
                .gesture(dragGesture(for: node))
            }
        }
    }

    private func edgeShape(source: CGPoint, target: CGPoint, value: Int, onTap: @escaping () -> Void) -> some View {
        ZStack {
            EdgePath(from: source, to: target)
                .stroke(
                    ReflectTheme.edgeLine.opacity(0.25 + Double(value) * 0.1),
                    style: StrokeStyle(lineWidth: 0.5 + CGFloat(value) * 0.3, lineCap: .round)
                )
            EdgePath(from: source, to: target)
                .stroke(Color.clear, lineWidth: 20)
                .contentShape(EdgePath(from: source, to: target).stroke(style: StrokeStyle(lineWidth: 20)))
                .onTapGesture(perform: onTap)
        }
    }

    private func dragGesture(for node: PositionedNode) -> some Gesture {
        DragGesture()
            .onChanged { value in
                viewModel.updatePosition(nodeId: node.id, to: value.location)
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.updatePosition(nodeId: node.id, to: value.location)
                }
                viewModel.persistPosition(nodeId: node.id, to: value.location)
            }
    }

    private var processingOverlay: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(ReflectTheme.accent)
                .scaleEffect(1.2)
            Text("Processing neural map…")
                .font(ReflectTheme.rounded(15, weight: .medium))
                .foregroundStyle(ReflectTheme.textMuted)
            Text("This usually takes 5–20 seconds.")
                .font(ReflectTheme.rounded(12))
                .foregroundStyle(ReflectTheme.textMuted.opacity(0.6))
        }
        .padding(ReflectTheme.spacingLG)
    }

    private func failureOverlay(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(ReflectTheme.accent)
            Text("Couldn't analyse this reflection")
                .font(ReflectTheme.serif(17, weight: .semibold))
                .foregroundStyle(ReflectTheme.textPrimary)
            Text(message)
                .font(ReflectTheme.rounded(13))
                .foregroundStyle(ReflectTheme.textMuted)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.retry() }
            }
            .buttonStyle(.borderedProminent)
            .tint(ReflectTheme.accent)
        }
        .padding(ReflectTheme.spacingLG)
    }

    private var transcriptArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReflectTheme.spacingLG) {
                Text(entry.polishedTranscript.isEmpty ? entry.rawTranscript : entry.polishedTranscript)
                    .font(ReflectTheme.serif(18))
                    .foregroundStyle(ReflectTheme.textPrimary)
                    .lineSpacing(8)

                Button { showRecording = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                        Text("Continue journal")
                    }
                    .font(ReflectTheme.rounded(15, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.vertical, 12).padding(.horizontal, 20)
                    .background(Capsule().fill(ReflectTheme.accent))
                    .shadow(color: ReflectTheme.accent.opacity(0.3), radius: 6, y: 3)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, ReflectTheme.spacingMD)
            }
            .padding(ReflectTheme.spacingLG)
        }
        .padding(.top, 140)
    }

    // MARK: - Chrome

    private var overlayChrome: some View {
        VStack {
            floatingTopBar

            Picker("View mode", selection: $viewMode) {
                Text("Map").tag(ViewMode.map)
                Text("Transcript").tag(ViewMode.transcript)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, ReflectTheme.spacingLG)
            .padding(.top, 4)

            Spacer()

            if viewMode == .map { bottomFilterStrip.padding(.bottom, 20) }
        }
    }

    private var floatingTopBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ReflectTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(ReflectTheme.cardSurface)
                            .shadow(color: ReflectTheme.softShadow, radius: 8, y: 2)
                    )
            }
            Spacer()
            Text(entry.aiGeneratedTitle)
                .font(ReflectTheme.serif(15, weight: .medium))
                .foregroundStyle(ReflectTheme.textPrimary.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Menu {
                Button { shareSession() } label: {
                    Label("Share session", systemImage: "square.and.arrow.up")
                }
                Button { showTranscript = true } label: {
                    Label("View transcript", systemImage: "doc.text")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ReflectTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(ReflectTheme.cardSurface)
                            .shadow(color: ReflectTheme.softShadow, radius: 8, y: 2)
                    )
            }
        }
        .padding(.horizontal, ReflectTheme.spacingLG)
        .padding(.top, ReflectTheme.spacingSM)
    }

    private var bottomFilterStrip: some View {
        let categories = viewModel.categories
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(label: "All", color: ReflectTheme.accent, isActive: activeFilter == nil) {
                    activeFilter = nil
                }
                ForEach(categories, id: \.storageKey) { category in
                    FilterPill(
                        label: category.label,
                        color: ReflectTheme.color(for: category),
                        isActive: activeFilter == category
                    ) {
                        activeFilter = category
                    }
                }
            }
            .padding(.horizontal, ReflectTheme.spacingLG)
        }
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [ReflectTheme.canvas.opacity(0), ReflectTheme.canvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var updateToast: some View {
        VStack {
            Spacer()
            Text("Entry updated")
                .font(ReflectTheme.rounded(14, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.8)))
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .zIndex(200)
    }

    // MARK: - Sheets

    @ViewBuilder
    private var nodeDetailSheet: some View {
        if let id = selectedNodeId,
           let node = viewModel.nodes.first(where: { $0.id == id }) {
            NodeDetailSheet(node: node, entry: entry, viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(ReflectTheme.cornerRadiusXL)
                .presentationBackground(ReflectTheme.cardSurface)
        }
    }

    @ViewBuilder
    private var edgeExplanationSheet: some View {
        if let edge = selectedEdge {
            EdgeExplanationSheet(
                sourceTheme: edge.source,
                targetTheme: edge.target,
                strength: edge.value,
                relationship: edge.relationship
            )
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Share

    private func shareSession() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateString = formatter.string(from: entry.date)
        let body = entry.polishedTranscript.isEmpty ? entry.rawTranscript : entry.polishedTranscript
        let text = """
        \(entry.aiGeneratedTitle)

        \(body)

        \u{2014} Reflected on \(dateString)
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
