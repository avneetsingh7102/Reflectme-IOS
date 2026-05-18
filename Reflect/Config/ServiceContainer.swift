import Foundation
import SwiftUI
@preconcurrency import SwiftData

/// Composition root. Holds the concrete service implementations the rest of
/// the app talks to via protocols.
///
/// Passed down the view tree via `@Environment(ServiceContainer.self)` so
/// ViewModels never reach for singletons.
@MainActor
@Observable
final class ServiceContainer {
    let entryProcessor: any EntryProcessor
    let deepDiveService: any DeepDiveService
    let authService: any AuthService
    let syncService: SupabaseSyncService

    init(
        entryProcessor: any EntryProcessor,
        deepDiveService: any DeepDiveService,
        authService: any AuthService,
        syncService: SupabaseSyncService
    ) {
        self.entryProcessor = entryProcessor
        self.deepDiveService = deepDiveService
        self.authService = authService
        self.syncService = syncService
    }

    /// Live wiring: real Groq + real Supabase (auth, sync) using values from
    /// `SecretsLoader` (override) → `AppConfig` (default).
    static func live() -> ServiceContainer {
        let groqKey = SecretsLoader.groqAPIKey()
        let supabaseURL = SecretsLoader.supabaseURL()
        let supabaseKey = SecretsLoader.supabaseAnonKey()

        let groqClient = GroqClient(apiKey: groqKey)
        let auth = SupabaseAuthService(url: supabaseURL, key: supabaseKey)
        let sync = SupabaseSyncService(url: supabaseURL, key: supabaseKey)

        return ServiceContainer(
            entryProcessor: GroqEntryProcessor(client: groqClient, model: AppConfig.entryProcessorModel),
            deepDiveService: GroqDeepDiveService(client: groqClient, model: AppConfig.deepDiveModel),
            authService: auth,
            syncService: sync
        )
    }

    /// Builds the repository the views use — local-first SwiftData, mirrored
    /// to Supabase in the background.
    func makeRepository(context: ModelContext) -> any JournalRepository {
        let local = SwiftDataJournalRepository(context: context)
        return SyncingJournalRepository(local: local, remote: syncService, auth: authService)
    }

    /// Builds the coordinator that handles auth-state side effects
    /// (cloud-pull on sign-in, local-wipe on sign-out).
    func makeAuthSyncCoordinator(context: ModelContext) -> AuthSyncCoordinator {
        AuthSyncCoordinator(
            auth: authService,
            pull: CloudPullService(context: context, remote: syncService),
            wipe: LocalWipeService(context: context)
        )
    }
}
