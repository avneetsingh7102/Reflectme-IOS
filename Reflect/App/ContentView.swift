import SwiftUI
@preconcurrency import SwiftData

/// Root navigation surface.
///
/// - Gates the app behind `LoginView` when there's no Supabase session and
///   no local-bypass.
/// - Owns the `NavigationPath` and registers two destinations:
///     * `JournalEntry` → `EntryView` (map + transcript modes share one screen)
///     * `SDNode`       → `NodeDetailView`
/// - Runs cloud-pull / local-wipe side-effects via `AuthSyncCoordinator`.
struct ContentView: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var modelContext

    @State private var path = NavigationPath()
    @State private var coordinator: AuthSyncCoordinator?

    var body: some View {
        Group {
            if services.authService.isAuthenticated {
                NavigationStack(path: $path) {
                    JournalListView(path: $path)
                        .navigationDestination(for: JournalEntry.self) { entry in
                            EntryView(entry: entry)
                        }
                        .navigationDestination(for: SDNode.self) { node in
                            NodeDetailView(node: node)
                        }
                        .overlay(alignment: .top) { pullingBanner }
                }
            } else {
                LoginView(authService: services.authService)
            }
        }
        .task {
            if coordinator == nil {
                coordinator = services.makeAuthSyncCoordinator(context: modelContext)
            }
        }
        .onChange(of: services.authService.isAuthenticated) { _, signedIn in
            Task { await coordinator?.handle(isAuthenticatedNow: signedIn) }
        }
    }

    @ViewBuilder
    private var pullingBanner: some View {
        if coordinator?.state == .pulling {
            HStack(spacing: 8) {
                ProgressView().tint(.white).scaleEffect(0.8)
                Text("Syncing your reflections…")
                    .font(ReflectTheme.rounded(12, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(ReflectTheme.primary))
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
