import Foundation
@preconcurrency import SwiftData

/// SwiftData-backed implementation of `JournalRepository`.
///
/// All operations are `@MainActor`-isolated because the `ModelContext` we use
/// is the one SwiftUI hands us via `@Environment(\.modelContext)`.
@MainActor
final class SwiftDataJournalRepository: JournalRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func createEntry(rawTranscript: String) throws -> JournalEntry {
        let entry = JournalEntry(
            rawTranscript: rawTranscript,
            aiGeneratedTitle: "Processing…",
            oneLineSummary: "Generating summary…",
            retryPending: true
        )
        context.insert(entry)
        try context.save()
        let total = (try? context.fetchCount(FetchDescriptor<JournalEntry>())) ?? -1
        let ctxID = ObjectIdentifier(context).hashValue
        print("📒 Created JournalEntry id=\(entry.id) chars=\(rawTranscript.count) | ctx=\(ctxID) totalAfterSave=\(total)")
        return entry
    }

    func appendTranscript(_ text: String, to entry: JournalEntry) throws {
        entry.rawTranscript += "\n\n" + text
        entry.retryPending = true
        entry.processingFailed = false
        try context.save()
    }

    func apply(_ result: ProcessedEntry, to entry: JournalEntry) throws {
        entry.aiGeneratedTitle = result.title.isEmpty ? entry.aiGeneratedTitle : result.title
        entry.oneLineSummary = result.summary
        entry.polishedTranscript = entry.rawTranscript

        for node in result.nodes where !entry.mapNodes.contains(where: { $0.id == node.id }) {
            let sdNode = SDNode(
                id: node.id,
                label: node.label,
                category: node.category,
                emotion: node.emotion,
                weight: 3
            )
            context.insert(sdNode)
            sdNode.session = entry
        }

        for edge in result.edges
        where !entry.mapLinks.contains(where: { $0.source == edge.sourceId && $0.target == edge.targetId }) {
            let sdLink = SDLink(
                source: edge.sourceId,
                target: edge.targetId,
                value: 1,
                relationship: edge.relationship
            )
            context.insert(sdLink)
            sdLink.session = entry
        }

        entry.retryPending = false
        entry.processingFailed = false
        try context.save()
        let total = (try? context.fetchCount(FetchDescriptor<JournalEntry>())) ?? -1
        let ctxID = ObjectIdentifier(context).hashValue
        print("💾 apply() saved | ctx=\(ctxID) total=\(total) entryNodes=\(entry.mapNodes.count)")
    }

    func markFailed(_ entry: JournalEntry) throws {
        entry.retryPending = false
        entry.processingFailed = true
        if entry.aiGeneratedTitle == "Processing…" {
            entry.aiGeneratedTitle = "Analysis failed"
        }
        if entry.oneLineSummary.isEmpty || entry.oneLineSummary == "Generating summary…" {
            entry.oneLineSummary = "Tap to retry"
        }
        try context.save()
    }

    func delete(_ entry: JournalEntry) throws {
        context.delete(entry)
        try context.save()
    }

    func setExpandedContent(_ content: String, for node: SDNode) throws {
        node.expandedContent = content
        try context.save()
    }

    func appendVoiceNote(_ note: String, to node: SDNode) throws {
        node.voiceNotes.append(note)
        try context.save()
    }

    func setPosition(_ position: CGPoint, for node: SDNode) throws {
        node.positionX = Double(position.x)
        node.positionY = Double(position.y)
        try context.save()
    }
}
