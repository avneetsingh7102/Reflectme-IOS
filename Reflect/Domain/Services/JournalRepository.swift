import Foundation

/// Persistence boundary for journal data.
///
/// All mutations go through this protocol so views and ViewModels never touch
/// `ModelContext` directly. The default implementation is SwiftData-backed.
@MainActor
protocol JournalRepository {
    func createEntry(rawTranscript: String) throws -> JournalEntry
    func appendTranscript(_ text: String, to entry: JournalEntry) throws
    func apply(_ result: ProcessedEntry, to entry: JournalEntry) throws
    func markFailed(_ entry: JournalEntry) throws
    func delete(_ entry: JournalEntry) throws
    func setExpandedContent(_ content: String, for node: SDNode) throws
    func appendVoiceNote(_ note: String, to node: SDNode) throws
    func setPosition(_ position: CGPoint, for node: SDNode) throws
}
