import Foundation

/// Generates a longer reflection on a single theme drawn from a transcript.
///
/// Called when the user taps a node and we lazily expand its detail sheet.
protocol DeepDiveService: Sendable {
    func expand(themeLabel: String, transcript: String) async throws -> String
}
