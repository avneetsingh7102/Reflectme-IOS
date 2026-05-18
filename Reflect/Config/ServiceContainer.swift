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

    init(entryProcessor: any EntryProcessor, 
         deepDiveService: any DeepDiveService,
         authService: any AuthService) {
        self.entryProcessor = entryProcessor
        self.deepDiveService = deepDiveService
        self.authService = authService
    }

    /// Default offline-first wiring: direct Groq calls, no backend.
    static func live() -> ServiceContainer {
        let client = GroqClient(apiKey: SecretsLoader.groqAPIKey())
        let auth = SupabaseAuthService(url: SecretsLoader.supabaseURL(), key: SecretsLoader.supabaseAnonKey())
        
        return ServiceContainer(
            entryProcessor: GroqEntryProcessor(client: client, model: AppConfig.entryProcessorModel),
            deepDiveService: GroqDeepDiveService(client: client, model: AppConfig.deepDiveModel),
            authService: auth
        )
    }

    /// Builds a repository bound to the given SwiftUI-provided `ModelContext`.
    func makeRepository(context: ModelContext) -> any JournalRepository {
        let local = SwiftDataJournalRepository(context: context)
        let remote = SupabaseSyncService(url: SecretsLoader.supabaseURL(), key: SecretsLoader.supabaseAnonKey())
        return SyncingJournalRepository(local: local, remote: remote, auth: authService)
    }
}
