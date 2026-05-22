import Foundation

/// Generates a longer reflection + a contextual Socratic question for a
/// single theme drawn from a transcript.
///
/// Called when the user taps a node and we lazily expand its detail surface.
/// The `DeepDive` return splits the long-form insight from the short question
/// so the UI can render each in the right place (Insight tab body vs.
/// "REFLECT ASKS" prompt block).
protocol DeepDiveService: Sendable {
    func expand(themeLabel: String, transcript: String) async throws -> DeepDive
}
