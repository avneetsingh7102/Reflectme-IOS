import Foundation
import SwiftUI

/// Repository decorator: every local write is mirrored to Supabase in the
/// background.
///
/// - Local-first: `SwiftDataJournalRepository` runs synchronously so the UI
///   updates immediately.
/// - Remote-best-effort: each call spawns a detached `Task` that talks to
///   `SupabaseSyncService`. Failures are logged but never thrown back to the
///   UI (offline-tolerant).
/// - Per-user: every row carries `user_id = auth.uid()`; Postgres RLS rejects
///   anything else.
@MainActor
final class SyncingJournalRepository: JournalRepository {
    private let local: SwiftDataJournalRepository
    private let remote: SupabaseSyncService
    private let auth: any AuthService

    init(local: SwiftDataJournalRepository, remote: SupabaseSyncService, auth: any AuthService) {
        self.local = local
        self.remote = remote
        self.auth = auth
    }

    private var userID: String? {
        // Don't expose the bypass sentinel — RLS would reject those calls.
        guard !auth.isLocalBypass else { return nil }
        return auth.currentUserID
    }

    // MARK: - Writes

    func createEntry(rawTranscript: String) throws -> JournalEntry {
        let entry = try local.createEntry(rawTranscript: rawTranscript)
        pushEntry(entry)
        return entry
    }

    func appendTranscript(_ text: String, to entry: JournalEntry) throws {
        try local.appendTranscript(text, to: entry)
        pushEntry(entry)
    }

    func apply(_ result: ProcessedEntry, to entry: JournalEntry) throws {
        try local.apply(result, to: entry)
        pushEntry(entry)
        pushNodes(of: entry)
        pushLinks(of: entry)
    }

    func markFailed(_ entry: JournalEntry) throws {
        try local.markFailed(entry)
        pushEntry(entry)
    }

    func delete(_ entry: JournalEntry) throws {
        let id = entry.id
        try local.delete(entry)
        Task { await remote.deleteEntry(id: id) }
    }

    func setDeepDive(_ dive: DeepDive, for node: SDNode) throws {
        try local.setDeepDive(dive, for: node)
        if let entry = node.session { pushNodes(of: entry) }
    }

    func appendVoiceNote(_ note: String, to node: SDNode) throws {
        try local.appendVoiceNote(note, to: node)
        if let entry = node.session { pushNodes(of: entry) }
    }

    func setPosition(_ position: CGPoint, for node: SDNode) throws {
        try local.setPosition(position, for: node)
        if let entry = node.session { pushNodes(of: entry) }
    }

    // MARK: - Outbound mappers

    private func pushEntry(_ entry: JournalEntry) {
        guard let userID else {
            print("⚠️ sync skipped: not signed in (entry=\(entry.id))")
            return
        }
        let row = SupabaseSyncService.EntryRow(
            id: entry.id,
            user_id: userID,
            date: entry.date,
            raw_transcript: entry.rawTranscript,
            polished_transcript: entry.polishedTranscript,
            ai_generated_title: entry.aiGeneratedTitle,
            one_line_summary: entry.oneLineSummary,
            retry_pending: entry.retryPending,
            processing_failed: entry.processingFailed,
            art_movement: entry.artMovement
        )
        Task { await remote.upsertEntry(row) }
    }

    private func pushNodes(of entry: JournalEntry) {
        guard let userID else { return }
        let rows = entry.mapNodes.map { node in
            SupabaseSyncService.NodeRow(
                id: node.id,
                entry_id: entry.id,
                user_id: userID,
                label: node.label,
                category_key: node.categoryKey,
                emotion_key: node.emotionKey,
                weight: node.weight,
                expanded_content: node.expandedContent,
                expanded_question: node.expandedQuestion,
                voice_notes: node.voiceNotes,
                position_x: node.positionX,
                position_y: node.positionY
            )
        }
        Task { await remote.upsertNodes(rows) }
    }

    private func pushLinks(of entry: JournalEntry) {
        guard let userID else { return }
        let rows = entry.mapLinks.map { link in
            SupabaseSyncService.LinkRow(
                id: link.id.uuidString,
                entry_id: entry.id,
                user_id: userID,
                source_id: link.source,
                target_id: link.target,
                value: link.value,
                relationship: link.relationship
            )
        }
        Task { await remote.upsertLinks(rows) }
    }
}
