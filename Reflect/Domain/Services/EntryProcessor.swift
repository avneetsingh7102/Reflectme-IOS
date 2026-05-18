import Foundation

/// Turns a raw transcript into a `ProcessedEntry` (title, summary, theme graph).
///
/// Implementations include a direct Groq client (offline-first) and a future
/// backend-routed processor. Both are swappable via `ServiceContainer`.
protocol EntryProcessor: Sendable {
    func process(transcript: String) async throws -> ProcessedEntry
}
