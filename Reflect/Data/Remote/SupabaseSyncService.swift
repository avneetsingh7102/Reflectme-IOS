import Foundation
import Supabase

/// Raw Supabase API calls for the three journal tables.
///
/// Wire types (`*Row`) mirror the Postgres columns exactly — snake_case keys,
/// nullability per the migration. Mapping to/from SwiftData `@Model` objects
/// happens in `SyncingJournalRepository` and `CloudPullService`.
actor SupabaseSyncService {
    private let client: SupabaseClient?
    private let isMock: Bool

    init(url: URL, key: String) {
        let isPlaceholder = url.absoluteString.contains("your-project-id")
            || key == "your-public-anon-key"
            || key == "PASTE_YOUR_SUPABASE_ANON_KEY"
            || key.isEmpty

        if isPlaceholder {
            self.isMock = true
            self.client = nil
            print("📒 Supabase Sync: MOCK mode (placeholder credentials)")
        } else {
            self.isMock = false
            self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
            print("✅ Supabase Sync: live client (\(url.host ?? "?"))")
        }
    }

    // MARK: - Wire types

    struct EntryRow: Codable, Sendable {
        let id: String
        let user_id: String
        let date: Date
        let raw_transcript: String
        let polished_transcript: String
        let ai_generated_title: String
        let one_line_summary: String
        let retry_pending: Bool
        let processing_failed: Bool?
        let art_movement: String?
    }

    struct NodeRow: Codable, Sendable {
        let id: String
        let entry_id: String
        let user_id: String
        let label: String
        let category_key: String
        let emotion_key: String
        let weight: Int
        let expanded_content: String?
        let voice_notes: [String]
        let position_x: Double?
        let position_y: Double?
    }

    struct LinkRow: Codable, Sendable {
        let id: String
        let entry_id: String
        let user_id: String
        let source_id: String
        let target_id: String
        let value: Int
        let relationship: String?
    }

    // MARK: - Upserts (called from SyncingJournalRepository)

    func upsertEntry(_ row: EntryRow) async {
        guard !isMock, let client else {
            print("📒 [Mock] upsert entry id=\(row.id) title=\(row.ai_generated_title)")
            return
        }
        do {
            try await client.from("entries").upsert(row).execute()
            print("☁️ upsert entry id=\(row.id)")
        } catch {
            print("❌ upsert entry id=\(row.id): \(error)")
        }
    }

    func upsertNodes(_ rows: [NodeRow]) async {
        guard !rows.isEmpty else { return }
        guard !isMock, let client else {
            print("📒 [Mock] upsert \(rows.count) nodes")
            return
        }
        do {
            try await client.from("nodes").upsert(rows).execute()
            print("☁️ upsert \(rows.count) nodes")
        } catch {
            print("❌ upsert nodes: \(error)")
        }
    }

    func upsertLinks(_ rows: [LinkRow]) async {
        guard !rows.isEmpty else { return }
        guard !isMock, let client else {
            print("📒 [Mock] upsert \(rows.count) links")
            return
        }
        do {
            try await client.from("links").upsert(rows).execute()
            print("☁️ upsert \(rows.count) links")
        } catch {
            print("❌ upsert links: \(error)")
        }
    }

    func deleteEntry(id: String) async {
        guard !isMock, let client else {
            print("📒 [Mock] delete entry id=\(id)")
            return
        }
        do {
            try await client.from("entries").delete().eq("id", value: id).execute()
            print("☁️ delete entry id=\(id) (cascades to nodes/links)")
        } catch {
            print("❌ delete entry id=\(id): \(error)")
        }
    }

    // MARK: - Fetches (called from CloudPullService on login)

    func fetchAllEntries(userID: String) async throws -> [EntryRow] {
        guard !isMock, let client else { return [] }
        let rows: [EntryRow] = try await client
            .from("entries")
            .select()
            .eq("user_id", value: userID)
            .order("date", ascending: false)
            .execute()
            .value
        print("☁️ fetched \(rows.count) entries for user=\(userID)")
        return rows
    }

    func fetchAllNodes(userID: String) async throws -> [NodeRow] {
        guard !isMock, let client else { return [] }
        let rows: [NodeRow] = try await client
            .from("nodes")
            .select()
            .eq("user_id", value: userID)
            .execute()
            .value
        print("☁️ fetched \(rows.count) nodes for user=\(userID)")
        return rows
    }

    func fetchAllLinks(userID: String) async throws -> [LinkRow] {
        guard !isMock, let client else { return [] }
        let rows: [LinkRow] = try await client
            .from("links")
            .select()
            .eq("user_id", value: userID)
            .execute()
            .value
        print("☁️ fetched \(rows.count) links for user=\(userID)")
        return rows
    }
}
