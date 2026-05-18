import Foundation
import Supabase

/// A service that handles the raw Supabase API calls for journal data,
/// with automatic mock fallback when keys are unconfigured.
actor SupabaseSyncService {
    private let client: SupabaseClient?
    private let isMock: Bool
    
    init(url: URL, key: String) {
        let isPlaceholder = url.absoluteString.contains("your-project-id") || key == "your-public-anon-key" || key.isEmpty
        
        if isPlaceholder {
            self.isMock = true
            self.client = nil
            print("📒 Supabase Sync: Running in MOCK Mode (Credentials are placeholders)")
        } else {
            self.isMock = false
            self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
            print("✅ Supabase Sync: Initialized live client")
        }
    }
    
    struct EntryDTO: Encodable {
        let id: String
        let user_id: UUID
        let transcript: String
        let title: String
        let summary: String
    }
    
    struct NodeDTO: Encodable {
        let id: String
        let entry_id: String
        let label: String
        let category: String
        let emotion: String
        let x: Double?
        let y: Double?
    }
    
    struct SyncNode: Sendable {
        let id: String
        let label: String
        let category: String
        let emotion: String
        let x: Double?
        let y: Double?
        
        init(id: String, label: String, category: String, emotion: String, x: Double?, y: Double?) {
            self.id = id
            self.label = label
            self.category = category
            self.emotion = emotion
            self.x = x
            self.y = y
        }
    }
    
    func upsertEntry(id: String, userID: UUID, transcript: String, title: String, summary: String) async {
        if isMock {
            print("📒 [Mock Sync] Upserted entry: \(title) (ID: \(id))")
            return
        }
        
        guard let client = client else { return }
        
        let dto = EntryDTO(
            id: id,
            user_id: userID,
            transcript: transcript,
            title: title,
            summary: summary
        )
        
        do {
            try await client
                .from("entries")
                .upsert(dto)
                .execute()
            print("✅ Supabase Sync: Upserted entry successfully")
        } catch {
            print("❌ Supabase Sync Error (Entry): \(error)")
        }
    }
    
    func upsertNodes(_ nodes: [SyncNode], for entryID: String) async {
        if isMock {
            print("📒 [Mock Sync] Upserted \(nodes.count) nodes for entry: \(entryID)")
            return
        }
        
        guard let client = client else { return }
        
        let dtos = nodes.map { node in
            NodeDTO(
                id: node.id,
                entry_id: entryID,
                label: node.label,
                category: node.category,
                emotion: node.emotion,
                x: node.x,
                y: node.y
            )
        }
        
        do {
            try await client
                .from("nodes")
                .upsert(dtos)
                .execute()
            print("✅ Supabase Sync: Upserted nodes successfully")
        } catch {
            print("❌ Supabase Sync Error (Nodes): \(error)")
        }
    }
    
    func deleteEntry(id: String) async {
        if isMock {
            print("📒 [Mock Sync] Deleted entry: \(id)")
            return
        }
        
        guard let client = client else { return }
        
        do {
            try await client
                .from("entries")
                .delete()
                .eq("id", value: id)
                .execute()
            print("✅ Supabase Sync: Deleted entry successfully")
        } catch {
            print("❌ Supabase Sync Error (Delete): \(error)")
        }
    }
}
