import SwiftUI
@preconcurrency import SwiftData

/// Home + directory for every locally-saved journal entry.
///
/// Powered by a SwiftData `@Query` so the list survives app launches and
/// stays reactive to mutations from anywhere in the app. The ViewModel only
/// owns search/filter/group transforms — never the entries themselves.
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
            topGradient

            if entries.isEmpty {
                EmptyStateView { showRecording = true }
                    .allowsHitTesting(true)
            } else if visibleEntries.isEmpty {
                noResultsState
            } else {
                entryList
            }

            // Record button must be the last interactive layer so it
            // sits on top of the list / empty-state and is always tappable.
            recordButton

            if showSideMenu { sideMenuOverlay }
        }
        .navigationTitle("")
        .toolbar { toolbarContent }
        .toolbarBackground(ReflectTheme.canvas.opacity(0.9), for: .navigationBar)
        .searchable(
            text: Binding(
                get: { viewModel?.searchText ?? "" },
                set: { viewModel?.searchText = $0 }
            ),
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search entries…"
        )
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
            let manualCount = (try? modelContext.fetchCount(FetchDescriptor<JournalEntry>())) ?? -1
            let ctxID = ObjectIdentifier(modelContext).hashValue
            print("📒 JournalListView onAppear | ctx=\(ctxID) @Query=\(entries.count) manualFetch=\(manualCount)")
            withAnimation { appeared = true }
        }
        .onChange(of: entries.count) { old, new in
            print("📒 JournalListView @Query entries: \(old) → \(new)")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 12) {
                roundIconButton(systemName: "line.3.horizontal") {
                    withAnimation(ReflectTheme.springSnappy) { showSideMenu = true }
                }
                Text("Reflect")
                    .font(ReflectTheme.serif(28, weight: .bold))
                    .foregroundStyle(ReflectTheme.textPrimary)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("All entries") { viewModel?.filter = .all }
                Menu("By emotion") {
                    ForEach(Emotion.allCases, id: \.self) { emotion in
                        Button(emotion.label) { viewModel?.filter = .emotion(emotion) }
                    }
                }
                Button("This week") { viewModel?.filter = .thisWeek }
                Button("This month") { viewModel?.filter = .thisMonth }
            } label: {
                roundIcon(
                    systemName: "line.3.horizontal.decrease.circle",
                    tint: (viewModel?.filter ?? .all) == .all ? ReflectTheme.textPrimary : ReflectTheme.accent
                )
            }
        }
    }

    // MARK: - Layers

    private var topGradient: some View {
        VStack {
            LinearGradient(
                colors: [ReflectTheme.accent.opacity(0.04), ReflectTheme.canvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
            .ignoresSafeArea()
            Spacer()
        }
    }

    private var sideMenuOverlay: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(ReflectTheme.springSnappy) { showSideMenu = false }
                }
            SideMenuView(showSettings: $showSettings)
                .frame(width: 280)
                .transition(.move(edge: .leading))
                .ignoresSafeArea()
        }
    }

    private var entryList: some View {
        List {
            greetingHeader
                .listRowInsets(EdgeInsets(top: ReflectTheme.spacingSM, leading: ReflectTheme.spacingLG, bottom: ReflectTheme.spacingLG, trailing: ReflectTheme.spacingLG))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            ForEach(monthGroups) { group in
                Section {
                    ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                        Button { path.append(entry) } label: {
                            JournalRowView(entry: entry)
                        }
                        .buttonStyle(CardPressStyle())
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)
                        .animation(ReflectTheme.springGentle.delay(Double(index) * 0.06), value: appeared)
                        .listRowInsets(EdgeInsets(top: 0, leading: ReflectTheme.spacingMD + 4, bottom: ReflectTheme.spacingSM + 4, trailing: ReflectTheme.spacingMD + 4))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel?.delete(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    monthHeader(group.title, count: group.entries.count)
                }
            }

            Color.clear
                .frame(height: 120)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
    }

    private func monthHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(ReflectTheme.rounded(12, weight: .bold))
                .foregroundStyle(ReflectTheme.textMuted)
                .textCase(.uppercase)
                .tracking(1.2)
            Circle()
                .fill(ReflectTheme.textMuted.opacity(0.3))
                .frame(width: 3, height: 3)
            Text("\(count) entr\(count == 1 ? "y" : "ies")")
                .font(ReflectTheme.rounded(12))
                .foregroundStyle(ReflectTheme.textMuted.opacity(0.7))
            Spacer()
        }
        .padding(.horizontal, ReflectTheme.spacingMD)
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ReflectTheme.greeting)
                    .font(ReflectTheme.serif(28, weight: .semibold))
                    .foregroundStyle(ReflectTheme.textPrimary)
                HStack(spacing: 6) {
                    Text(ReflectTheme.greetingEmoji).font(.system(size: 13))
                    Text(timeString)
                        .font(ReflectTheme.rounded(13))
                        .foregroundStyle(ReflectTheme.textMuted)
                    Circle()
                        .fill(ReflectTheme.textMuted.opacity(0.3))
                        .frame(width: 3, height: 3)
                    Text("\(entries.count) reflection\(entries.count == 1 ? "" : "s")")
                        .font(ReflectTheme.rounded(13))
                        .foregroundStyle(ReflectTheme.textMuted)
                }
            }
            Divider().background(ReflectTheme.separator.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var noResultsState: some View {
        VStack(spacing: ReflectTheme.spacingMD) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(ReflectTheme.textMuted.opacity(0.5))
            Text("No matching entries")
                .font(ReflectTheme.serif(18, weight: .semibold))
                .foregroundStyle(ReflectTheme.textPrimary)
            Text("Try a different search or clear the filter.")
                .font(ReflectTheme.rounded(13))
                .foregroundStyle(ReflectTheme.textMuted)
                .multilineTextAlignment(.center)
            Button("Clear filter") {
                viewModel?.filter = .all
                viewModel?.searchText = ""
            }
            .font(ReflectTheme.rounded(14, weight: .medium))
            .foregroundStyle(ReflectTheme.accent)
        }
        .padding(ReflectTheme.spacingLG)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recordButton: some View {
        PulsingOrbButton(isRecording: false) {
            showRecording = true
        }
        .padding(.bottom, ReflectTheme.spacingLG)
    }

    private func handleNewEntry(_ entry: JournalEntry?) {
        // Explicitly save context to ensure the entry is flushed to the
        // persistent store *before* any view transitions happen.  This
        // nudges @Query to pick up the new row.
        try? modelContext.save()

        showRecording = false

        guard let entry else { return }

        print("📒 handleNewEntry → navigating to entry id=\(entry.id) title=\(entry.aiGeneratedTitle)")

        Task { @MainActor in
            // Wait for the fullScreenCover dismissal animation to finish
            // before pushing the neural map view.
            try? await Task.sleep(for: .milliseconds(500))
            path.append(entry)
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE \u{00B7} h:mm a"
        return formatter.string(from: Date())
    }

    @ViewBuilder
    private func roundIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            roundIcon(systemName: systemName, tint: ReflectTheme.textPrimary)
        }
    }

    private func roundIcon(systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(ReflectTheme.cardSurface)
                    .shadow(color: ReflectTheme.softShadow, radius: 6, y: 2)
            )
    }
}

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
