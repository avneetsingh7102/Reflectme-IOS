import SwiftUI
@preconcurrency import SwiftData

/// Neural map for one journal entry — redesigned per Reflect Mobile spec.
///
/// Layout (top → bottom):
/// 1. Top bar: back/menu chevron · "WEEK N" mono on the right.
/// 2. Eyebrow ("Neural map · N nodes") + serif H1 ("What you've been thinking about.").
/// 3. Horizontal filter chips: All / Self / Relationships / Growth / Authenticity.
/// 4. Map canvas — paper-dot field, clean flat circles, dashed curved edges.
/// 5. Bottom-centre `PulsingRing` (68pt) with "NEW REFLECTION" cue.
struct NeuralMapView: View {
    let entry: JournalEntry

    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: NeuralMapViewModel?
    @State private var activeFilter: NodeCategory? = nil
    @State private var showRecording = false

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let vm = viewModel {
                    LoadedMap(viewModel: vm, entry: entry,
                              canvasSize: proxy.size,
                              activeFilter: $activeFilter,
                              dismiss: dismiss,
                              showRecording: $showRecording)
                } else {
                    bootstrap
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
        .fullScreenCover(isPresented: $showRecording) {
            RecordingView(
                mode: .appendingTo(entry),
                onFinished: { _ in showRecording = false },
                onClosed: { showRecording = false }
            )
        }
    }

    private var bootstrap: some View {
        ZStack {
            ReflectTheme.canvas.ignoresSafeArea()
            ProgressView().tint(ReflectTheme.primary)
        }
    }
}

// MARK: - Loaded surface

private struct LoadedMap: View {
    let viewModel: NeuralMapViewModel
    let entry: JournalEntry
    let canvasSize: CGSize
    @Binding var activeFilter: NodeCategory?
    let dismiss: DismissAction
    @Binding var showRecording: Bool

    @State private var appeared = false

    var body: some View {
        ZStack {
            ReflectTheme.canvas.ignoresSafeArea()
            paperDotField

            VStack(spacing: 0) {
                topBar
                titleBlock
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                filterStrip
                    .padding(.bottom, 4)

                ZStack {
                    switch viewModel.state {
                    case .processing, .idle:   processingOverlay
                    case .failed(let m):       failureOverlay(message: m)
                    case .ready:               graphLayer
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) { recordRing }
            }
        }
        .task {
            withAnimation(.easeOut(duration: 0.3)) { appeared = true }
        }
    }

    // MARK: - Visual layers

    private var paperDotField: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 18
            ctx.opacity = 0.5
            for x in stride(from: 0, through: size.width, by: spacing) {
                for y in stride(from: 0, through: size.height, by: spacing) {
                    let rect = CGRect(x: x - 0.5, y: y - 0.5, width: 1, height: 1)
                    ctx.fill(Path(ellipseIn: rect), with: .color(ReflectTheme.ink.opacity(0.06)))
                }
            }
        }
        .ignoresSafeArea()
    }

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
            Text(weekLabel)
                .font(ReflectTheme.mono(11))
                .foregroundStyle(ReflectTheme.inkSoft)
                .tracking(0.4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Neural map · \(viewModel.nodes.count) node\(viewModel.nodes.count == 1 ? "" : "s")")
                .eyebrowStyle(color: ReflectTheme.mustard500)
            Text("What you've been\nthinking about.")
                .font(.system(size: 26, weight: .medium, design: .serif))
                .foregroundStyle(ReflectTheme.ink)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(label: "All", isActive: activeFilter == nil) {
                    activeFilter = nil
                }
                ForEach(viewModel.categories, id: \.storageKey) { category in
                    FilterPill(label: category.label, isActive: activeFilter == category) {
                        activeFilter = (activeFilter == category) ? nil : category
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var graphLayer: some View {
        let positioned = viewModel.nodes
        let edges = viewModel.edges
        ZStack {
            // Edges
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
            Button("Retry") {
                Task { await viewModel.retry() }
            }
            .buttonStyle(.borderedProminent)
            .tint(ReflectTheme.primary)
        }
        .padding(20)
    }

    private var recordRing: some View {
        VStack(spacing: 8) {
            PulsingRing(mode: .resting, size: 68) {
                showRecording = true
            }
            Text("NEW REFLECTION")
                .font(ReflectTheme.rounded(10, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(ReflectTheme.inkSoft)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Helpers

    private func isDimmed(_ node: PositionedNode) -> Bool {
        guard let activeFilter else { return false }
        return node.category != activeFilter
    }

    private var weekLabel: String {
        let cal = Calendar.current
        let week = cal.component(.weekOfYear, from: entry.date)
        return "WEEK \(week)"
    }
}

// MARK: - Map node

private struct MapNodeView: View {
    let node: PositionedNode
    let isDimmed: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(ReflectTheme.color(for: node.emotion))
                .frame(width: diameter, height: diameter)
                .overlay(
                    Circle().stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                )
            // Subtle gloss top-left
            Ellipse()
                .fill(Color.white.opacity(0.22))
                .frame(width: diameter * 0.36, height: diameter * 0.18)
                .offset(x: -diameter * 0.18, y: -diameter * 0.20)
            if diameter >= 56 {
                Text(node.label)
                    .font(.system(size: min(13, diameter * 0.20), weight: .medium, design: .serif))
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
