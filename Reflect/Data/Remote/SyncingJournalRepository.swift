import Foundation
import SwiftUI

/// A repository decorator that performs operations locally via SwiftData
/// and then mirrors them to Supabase in the background.
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
    
    private var userID: UUID? {
        guard let id = auth.currentUserID else { return nil }
        return UUID(uuidString: id)
    }
    
    func createEntry(rawTranscript: String) throws -> JournalEntry {
        let entry = try local.createEntry(rawTranscript: rawTranscript)
        sync(entry)
        return entry
    }
    
    func appendTranscript(_ text: String, to entry: JournalEntry) throws {
        try local.appendTranscript(text, to: entry)
        sync(entry)
    }
    
    func apply(_ result: ProcessedEntry, to entry: JournalEntry) throws {
        try local.apply(result, to: entry)
        sync(entry)
        syncNodes(for: entry)
    }
    
    func markFailed(_ entry: JournalEntry) throws {
        try local.markFailed(entry)
        sync(entry)
    }
    
    func delete(_ entry: JournalEntry) throws {
        let id = entry.id
        try local.delete(entry)
        Task {
            await remote.deleteEntry(id: id)
        }
    }
    
    func setExpandedContent(_ content: String, for node: SDNode) throws {
        try local.setExpandedContent(content, for: node)
        if let entry = node.session {
            sync(entry)
            syncNodes(for: entry)
        }
    }
    
    func appendVoiceNote(_ note: String, to node: SDNode) throws {
        try local.appendVoiceNote(note, to: node)
        if let entry = node.session {
            syncNodes(for: entry)
        }
    }
    
    func setPosition(_ position: CGPoint, for node: SDNode) throws {
        try local.setPosition(position, for: node)
        if let entry = node.session {
            syncNodes(for: entry)
        }
    }
    
    private func sync(_ entry: JournalEntry) {
        guard let userID = userID else { return }
        
        let id = entry.id
        let transcript = entry.rawTranscript
        let title = entry.aiGeneratedTitle
        let summary = entry.oneLineSummary
        
        Task {
            await remote.upsertEntry(
                id: id,
                userID: userID,
                transcript: transcript,
                title: title,
                summary: summary
            )
        }
    }
    
    private func syncNodes(for entry: JournalEntry) {
        guard userID != nil else { return }
        
        let entryID = entry.id
        let syncNodes = entry.mapNodes.map { node in
            SupabaseSyncService.SyncNode(
                id: node.id,
                label: node.label,
                category: node.categoryKey,
                emotion: node.emotionKey,
                x: node.positionX,
                y: node.positionY
            )
        }
        
        Task {
            await remote.upsertNodes(syncNodes, for: entryID)
        }
    }
}
