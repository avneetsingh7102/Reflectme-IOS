import Foundation

/// Compile-time and runtime configuration for the app.
///
/// Keep this small and strongly-typed; anything network-related lives behind
/// the `EntryProcessor` / `DeepDiveService` protocols so swapping a backend
/// later is a `ServiceContainer` change, not a touch-the-views change.
enum AppConfig {
    /// Sentinel used to detect an unset API key (so the client can fail fast
    /// with a useful error rather than calling Groq with garbage).
    static let placeholderAPIKey = "PASTE_YOUR_GROQ_KEY_HERE"

    /// Default model used when extracting themes from a transcript.
    static let entryProcessorModel = "llama-3.3-70b-versatile"

    /// Default model used when expanding a single theme into a paragraph.
    static let deepDiveModel = "llama-3.1-8b-instant"

    /// Where the optional FastAPI backend would live. Swap this in
    /// `ServiceContainer` when a `BackendEntryProcessor` exists.
    static var backendBaseURL: URL? {
        #if targetEnvironment(simulator)
        return URL(string: "http://localhost:8000")
        #else
        return nil
        #endif
    }

    /// Supabase project URL.
    static let supabaseURL = URL(string: "https://your-project-id.supabase.co")!
    
    /// Supabase public anon key.
    static let supabaseAnonKey = "your-public-anon-key"
}
