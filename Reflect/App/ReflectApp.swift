import SwiftUI
@preconcurrency import SwiftData

@main
struct ReflectApp: App {
    @AppStorage("isDarkMode") private var isDarkMode = false

    @State private var services = ServiceContainer.live()

    /// Explicit container with error logging.  When `ModelContainer(for:)`
    /// throws (usually a schema-migration failure) the default `.modelContainer`
    /// modifier silently falls back to an in-memory store — which makes every
    /// @Query come back empty after the next launch.  Building the container
    /// ourselves lets us catch that and at least log it.
    private let container: ModelContainer = {
        let schema = Schema([JournalEntry.self, SDNode.self, SDLink.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            print("✅ ModelContainer loaded — store: \(config.url.path())")
            return container
        } catch {
            // Log the error and fall back to the default persistent container.
            print("⚠️ Failed to create ModelContainer with custom config: \(error)")
            // The default initializer will use the standard location and may succeed.
            do {
                let fallback = try ModelContainer(for: schema)
                print("✅ Fallback ModelContainer loaded using default configuration")
                return fallback
            } catch {
                // As a last resort, use an in‑memory store to keep the app functional.
                print("❗️ Critical: ModelContainer creation failed. Using in‑memory store. Error: \(error)")
                return try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(services)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
        .modelContainer(container)
    }
}
