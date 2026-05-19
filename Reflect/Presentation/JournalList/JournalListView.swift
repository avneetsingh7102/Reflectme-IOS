import SwiftUI
@preconcurrency import SwiftData

/// Home / journal directory — redesigned per Reflect Mobile spec.
///
/// Layout:
/// 1. Top bar: menu (left), entry count mono (right).
/// 2. Title block: eyebrow "Journal", H1 "Every reflection, in order."
/// 3. Inline pill search bar + horizontal filter chips.
/// 4. Month-sectioned list with serif rows on white cards.
/// 5. Floating bottom-centre `PulsingRing` FAB + "NEW REFLECTION" cue.
struct JournalListView: View {
    @Binding var path: NavigationPath

    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    @State private var viewModel: JournalListViewModel?
    @State private var showRecording = false
    @State private var showSettings = false
    @State private var showSideMenu = false
    @State private var appeared = false

    private var visibleEntries: [JournalEntry] {
        viewModel?.visible(entries) ?? entries
    }

    private var monthGroups: [JournalListViewModel.MonthGroup] {
        viewModel?.grouped(visibleEntries) ?? []
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ReflectTheme.canvas.ignoresSafeArea()

            if entries.isEmpty {
                emptyStateColumn
            } else {
                contentList
            }

            recordRingFAB

            if showSideMenu { sideMenuOverlay }
        }
        .navigationTitle("")
        .toolbar { toolbarContent }
        .toolbarBackground(ReflectTheme.canvas.opacity(0.9), for: .navigationBar)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .fullScreenCover(isPresented: $showRecording) {
            RecordingView(
                mode: .newSession,
                onFinished: handleNewEntry,
                onClosed: { showRecording = false }
            )
        }
        .task {
            if viewModel == nil {
                let repo = services.makeRepository(context: modelContext)
                viewModel = JournalListViewModel(repository: repo)
            }
        }
        .onAppear {
            print("📒 JournalListView appeared with \(entries.count) entries")
            withAnimation { appeared = true }
        }
    }

    // MARK: - Sub-views

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { withAnimation(ReflectTheme.springSnappy) { showSideMenu = true } } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ReflectTheme.ink)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.06)))
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Text("\(entries.count) ENTRIES")
                .font(ReflectTheme.mono(11))
                .tracking(0.4)
                .foregroundStyle(ReflectTheme.inkSoft)
        }
    }

    private var contentList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                titleBlock
                    .padding(.horizontal, ReflectTheme.edge)
                    .padding(.bottom, 12)
                searchAndFilters
                    .padding(.horizontal, ReflectTheme.edge)
                    .padding(.bottom, 14)

                if visibleEntries.isEmpty {
                    noResultsBlock
                        .padding(.top, 40)
                } else {
                    ForEach(monthGroups) { group in
                        monthSection(group: group)
                    }
                }

                Color.clear.frame(height: 140)
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Journal").eyebrowStyle(color: ReflectTheme.mustard500)
            Text("Every reflection,\nin order.")
                .font(.system(size: 30, weight: .medium, design: .serif))
                .foregroundStyle(ReflectTheme.ink)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchAndFilters: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ReflectTheme.inkFaint)
                TextField("Search your reflections…",
                          text: Binding(get: { viewModel?.searchText ?? "" },
                                        set: { viewModel?.searchText = $0 }))
                    .font(ReflectTheme.rounded(14))
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(Color.white)
                    .overlay(Capsule().stroke(ReflectTheme.separator, lineWidth: 1))
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(label: "All",
                               isActive: viewModel?.filter == .all) { viewModel?.filter = .all }
                    FilterChip(label: "This Week",
                               isActive: viewModel?.filter == .thisWeek) { viewModel?.filter = .thisWeek }
                    FilterChip(label: "This Month",
                               isActive: viewModel?.filter == .thisMonth) { viewModel?.filter = .thisMonth }
                    ForEach(Emotion.allCases, id: \.self) { e in
                        FilterChip(label: e.label,
                                   isActive: viewModel?.filter == .emotion(e)) { viewModel?.filter = .emotion(e) }
                    }
                }
            }
        }
    }

    private func monthSection(group: JournalListViewModel.MonthGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.title)
                    .font(ReflectTheme.serif(18, weight: .medium))
                    .foregroundStyle(ReflectTheme.ink)
                Spacer()
                Text("\(group.entries.count) entr\(group.entries.count == 1 ? "y" : "ies")")
                    .font(ReflectTheme.mono(11))
                    .foregroundStyle(ReflectTheme.inkFaint)
            }
            .padding(.horizontal, ReflectTheme.edge)
            .padding(.bottom, 4)

            VStack(spacing: 8) {
                ForEach(group.entries) { entry in
                    Button { path.append(entry) } label: {
                        JournalRowView(entry: entry)
                    }
                    .buttonStyle(CardPressStyle())
                }
            }
            .padding(.horizontal, ReflectTheme.spacingMD)
            .padding(.bottom, 14)
        }
    }

    private var emptyStateColumn: some View {
        VStack(spacing: 18) {
            Spacer()
            // Quill + paper illustration
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(ReflectTheme.separator, lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                    .frame(width: 100, height: 120)
                    .overlay(
                        VStack(spacing: 8) {
                            Capsule().fill(ReflectTheme.surface3).frame(width: 70, height: 2)
                            Capsule().fill(ReflectTheme.surface3).frame(width: 60, height: 2)
                            Capsule().fill(ReflectTheme.surface3).frame(width: 64, height: 2)
                            Capsule().fill(ReflectTheme.surface3).frame(width: 52, height: 2)
                        }
                        .padding(.top, 24)
                        , alignment: .top
                    )

                Image(systemName: "pencil.tip")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(ReflectTheme.mustard500)
                    .rotationEffect(.degrees(45))
                    .offset(x: 36, y: -32)
            }
            .padding(.bottom, 6)

            Text("Your first page.")
                .font(.system(size: 22, weight: .medium, design: .serif))
                .foregroundStyle(ReflectTheme.ink)
            Text("Tap the ring below to begin your first reflection.")
                .font(ReflectTheme.serif(14))
                .foregroundStyle(ReflectTheme.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            Spacer().frame(height: 160)
        }
        .frame(maxWidth: .infinity)
    }

    private var noResultsBlock: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30))
                .foregroundStyle(ReflectTheme.inkFaint.opacity(0.6))
            Text("No matching entries")
                .font(ReflectTheme.serif(18, weight: .medium))
                .foregroundStyle(ReflectTheme.ink)
            Button("Clear filters") {
                viewModel?.filter = .all
                viewModel?.searchText = ""
            }
            .font(ReflectTheme.rounded(14, weight: .semibold))
            .foregroundStyle(ReflectTheme.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var recordRingFAB: some View {
        VStack(spacing: 8) {
            PulsingRing(mode: .resting, size: 68) {
                showRecording = true
            }
            Text("NEW REFLECTION")
                .font(ReflectTheme.rounded(10, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(ReflectTheme.inkSoft)
        }
        .padding(.bottom, 28)
    }

    private var sideMenuOverlay: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(ReflectTheme.springSnappy) { showSideMenu = false }
                }
            SideMenuView(showSettings: $showSettings)
                .frame(width: 300)
                .transition(.move(edge: .leading))
                .ignoresSafeArea()
        }
    }

    // MARK: - New entry navigation

    private func handleNewEntry(_ entry: JournalEntry?) {
        showRecording = false
        guard let entry else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            // After recording, drop the user into the neural map for that entry
            // (so they see the AI-extracted nodes immediately).
            path.append(MapRoute(entry: entry))
        }
    }
}

// MARK: - Row + supporting types

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Horizontal filter chip — active = ink-black background, inactive = outlined.
private struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(ReflectTheme.rounded(12, weight: .semibold))
                .foregroundStyle(isActive ? Color.white : ReflectTheme.inkSoft)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isActive ? ReflectTheme.ink : Color.clear)
                        .overlay(
                            Capsule().stroke(
                                isActive ? Color.clear : ReflectTheme.separator,
                                lineWidth: 1
                            )
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

/// Navigation route to push the neural map for a specific entry. Wrapping in
/// a struct lets us route to either `JournalEntryView` or `NeuralMapView`
/// from the same NavigationPath.
struct MapRoute: Hashable {
    let entry: JournalEntry
    func hash(into hasher: inout Hasher) { hasher.combine(entry.id) }
    static func == (lhs: MapRoute, rhs: MapRoute) -> Bool { lhs.entry.id == rhs.entry.id }
}
