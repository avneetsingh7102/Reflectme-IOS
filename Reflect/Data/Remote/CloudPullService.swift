import Foundation
@preconcurrency import SwiftData

/// One-shot hydration of the local SwiftData store from Supabase.
///
/// Called by `AuthSyncCoordinator` immediately after a successful sign-in.
/// Behaviour: fetch every row owned by `auth.uid()`, then upsert each into
/// the local context. Existing local rows with the same `id` are overwritten,
/// so a fresh install pulls everything and an existing install reconciles
/// without duplicates.
@MainActor
final class CloudPullService {
    enum Failure: Error, LocalizedError {
        case noUser
        var errorDescription: String? {
            switch self {
            case .noUser: return "Not signed in."
            }
        }
    }

    private let context: ModelContext
    private let remote: SupabaseSyncService

    init(context: ModelContext, remote: SupabaseSyncService) {
        self.context = context
        self.remote = remote
    }

    func pullAll(userID: String) async throws {
        print("⬇️ CloudPull starting for user=\(userID)")
        async let entriesTask = remote.fetchAllEntries(userID: userID)
        async let nodesTask = remote.fetchAllNodes(userID: userID)
        async let linksTask = remote.fetchAllLinks(userID: userID)

        let (entries, nodes, links) = try await (entriesTask, nodesTask, linksTask)

        // Build lookups so we can wire relationships after insert.
        var entryById: [String: JournalEntry] = [:]

        // 1. Upsert entries
        for row in entries {
            let entry = upsertEntry(row)
            entryById[row.id] = entry
        }

        // 2. Upsert nodes
        for row in nodes {
            upsertNode(row, parents: entryById)
        }

        // 3. Upsert links
        for row in links {
            upsertLink(row, parents: entryById)
        }

        try context.save()
        print("⬇️ CloudPull complete: \(entries.count) entries, \(nodes.count) nodes, \(links.count) links")
    }

    // MARK: - Upsert helpers (find-or-create, then patch fields)

    @discardableResult
    private func upsertEntry(_ row: SupabaseSyncService.EntryRow) -> JournalEntry {
        let id = row.id
        let descriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.id == id })
        if let existing = try? context.fetch(descriptor).first {
            existing.date = row.date
            existing.rawTranscript = row.raw_transcript
            existing.polishedTranscript = row.polished_transcript
            existing.aiGeneratedTitle = row.ai_generated_title
            existing.oneLineSummary = row.one_line_summary
            existing.retryPending = row.retry_pending
            existing.processingFailed = row.processing_failed
            existing.artMovement = row.art_movement
            return existing
        }
        let entry = JournalEntry(
            id: row.id,
            date: row.date,
            rawTranscript: row.raw_transcript,
            polishedTranscript: row.polished_transcript,
            aiGeneratedTitle: row.ai_generated_title,
            oneLineSummary: row.one_line_summary,
            retryPending: row.retry_pending,
            processingFailed: row.processing_failed,
            artMovement: row.art_movement
        )
        context.insert(entry)
        return entry
    }

    private func upsertNode(_ row: SupabaseSyncService.NodeRow, parents: [String: JournalEntry]) {
        guard let parent = parents[row.entry_id] else { return }
        let id = row.id
        let descriptor = FetchDescriptor<SDNode>(predicate: #Predicate { $0.id == id })
        if let existing = try? context.fetch(descriptor).first {
            existing.label = row.label
            existing.categoryKey = row.category_key
            existing.emotionKey = row.emotion_key
            existing.weight = row.weight
            existing.expandedContent = row.expanded_content
            existing.voiceNotes = row.voice_notes
            existing.positionX = row.position_x
            existing.positionY = row.position_y
            existing.session = parent
            return
        }
        let node = SDNode(
            id: row.id,
            label: row.label,
            category: NodeCategory(apiString: row.category_key),
            emotion: Emotion(apiString: row.emotion_key),
            weight: row.weight,
            expandedContent: row.expanded_content,
            voiceNotes: row.voice_notes,
            position: (row.position_x.flatMap { x in row.position_y.map { y in CGPoint(x: x, y: y) } })
        )
        context.insert(node)
        node.session = parent
    }

    private func upsertLink(_ row: SupabaseSyncService.LinkRow, parents: [String: JournalEntry]) {
        guard let parent = parents[row.entry_id] else { return }
        let parentID = parent.id
        // Match by (entry_id, source, target) since SDLink uses its own UUID locally.
        let descriptor = FetchDescriptor<SDLink>(
            predicate: #Predicate { link in
                link.source == row.source_id
                    && link.target == row.target_id
                    && link.session?.id == parentID
            }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.value = row.value
            existing.relationship = row.relationship
            return
        }
        let link = SDLink(
            source: row.source_id,
            target: row.target_id,
            value: row.value,
            relationship: row.relationship
        )
        context.insert(link)
        link.session = parent
    }
}
