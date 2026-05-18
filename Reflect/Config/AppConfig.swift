import Foundation

/// Compile-time and runtime configuration for the app.
///
/// Keep this small and strongly-typed; anything network-related lives behind
/// the `EntryProcessor` / `DeepDiveService` / `AuthService` protocols so
/// swapping a backend later is a `ServiceContainer` change, not a touch-the-views
/// change.
enum AppConfig {
    /// Sentinel used to detect an unset Groq API key (so the client can fail
    /// fast with a useful error rather than calling Groq with garbage).
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

    /// Supabase project URL — public, embedded in client builds by design.
    /// Override in Secrets.plist if you ever spin up a second environment.
    static let supabaseURL = URL(string: "https://eafhnkxrtwocvuvuhwqf.supabase.co")!

    /// Supabase publishable anon key — designed to be public; Row Level
    /// Security in Postgres scopes every query to `auth.uid()`.
    static let supabaseAnonKey = "sb_publishable_D99Kex5dQyGQEkphRpq1cw_9QtJErdZ"
}
