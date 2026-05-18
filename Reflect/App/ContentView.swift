import SwiftUI
@preconcurrency import SwiftData

/// Root navigation surface. Gates the app on auth, owns the navigation path,
/// and runs the cloud-pull / local-wipe side-effects via
/// `AuthSyncCoordinator`.
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
                            NeuralMapView(entry: entry)
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
            .background(Capsule().fill(ReflectTheme.accent))
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
