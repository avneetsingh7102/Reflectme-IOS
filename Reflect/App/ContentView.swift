import SwiftUI
@preconcurrency import SwiftData

/// Root navigation surface. Owns the `NavigationPath` and routes
/// `JournalEntry` values onto the neural map.
///
/// We navigate with the entry *object*, not its id, so the destination view
/// gets the same in-memory instance we just inserted — no `@Query` race.
struct ContentView: View {
    @Environment(ServiceContainer.self) private var services
    @State private var path = NavigationPath()

    var body: some View {
        if services.authService.isAuthenticated {
            NavigationStack(path: $path) {
                JournalListView(path: $path)
                    .navigationDestination(for: JournalEntry.self) { entry in
                        NeuralMapView(entry: entry)
                    }
            }
        } else {
            LoginView(authService: services.authService)
        }
    }
}
