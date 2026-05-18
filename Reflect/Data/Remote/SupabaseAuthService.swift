import Foundation
import Supabase
import Observation

/// Supabase-backed `AuthService` implementation.
///
/// Falls back to a mock that auto-signs-in if the project URL or key still
/// look like placeholders — keeps the simulator usable without secrets.
@MainActor
@Observable
final class SupabaseAuthService: AuthService {
    private let client: SupabaseClient?
    private let isMock: Bool

    private(set) var currentSession: Session?
    private var mockUserID: String?
    private var mockIsAuthenticated: Bool = false

    init(url: URL, key: String) {
        let isPlaceholder = url.absoluteString.contains("your-project-id")
            || key == "your-public-anon-key"
            || key == "PASTE_YOUR_SUPABASE_ANON_KEY"
            || key.isEmpty

        if isPlaceholder {
            self.isMock = true
            self.client = nil
            print("📒 Supabase Auth: MOCK mode (placeholder credentials)")
        } else {
            self.isMock = false
            let client = SupabaseClient(supabaseURL: url, supabaseKey: key)
            self.client = client
            self.currentSession = client.auth.currentSession
            print("✅ Supabase Auth: live client (\(url.host ?? "?"))")

            // Subscribe to auth state changes so isAuthenticated reflects
            // sign-in / sign-out / token refresh in real time.
            Task { [weak self] in
                guard let self else { return }
                for await (event, session) in client.auth.authStateChanges {
                    print("🔐 Auth event: \(event) → user=\(session?.user.id.uuidString ?? "nil")")
                    self.currentSession = session
                }
            }
        }
    }

    var currentUserID: String? {
        if isMock { return mockUserID }
        return currentSession?.user.id.uuidString
    }

    var isAuthenticated: Bool {
        if isMock { return mockIsAuthenticated }
        return currentSession != nil
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        if isMock {
            try await simulateMockSignIn(provider: "Apple")
            return
        }
        guard let client else { throw AuthFailure.notConfigured }
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        currentSession = session
        print("✅ Apple sign-in success: user=\(session.user.id.uuidString)")
    }

    func signInWithGoogle(idToken: String, accessToken: String?) async throws {
        if isMock {
            try await simulateMockSignIn(provider: "Google")
            return
        }
        guard let client else { throw AuthFailure.notConfigured }
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken)
        )
        currentSession = session
        print("✅ Google sign-in success: user=\(session.user.id.uuidString)")
    }

    func signOut() async throws {
        print("🔐 Supabase Auth: signing out")
        if isMock {
            mockIsAuthenticated = false
            mockUserID = nil
            return
        }
        try await client?.auth.signOut()
        currentSession = nil
    }

    private func simulateMockSignIn(provider: String) async throws {
        print("📒 Mock \(provider) sign-in (Supabase placeholders detected)")
        try await Task.sleep(nanoseconds: 600_000_000)
        mockUserID = "00000000-0000-0000-0000-000000000001"
        mockIsAuthenticated = true
    }

    enum AuthFailure: LocalizedError {
        case notConfigured

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Supabase isn't configured — check AppConfig / Secrets.plist."
            }
        }
    }
}
