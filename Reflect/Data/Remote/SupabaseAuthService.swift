import Foundation
import Supabase
import Observation

/// Implementation of AuthService using Supabase, with automatic mock fallback when keys are unconfigured.
@MainActor
@Observable
final class SupabaseAuthService: AuthService {
    private let client: SupabaseClient?
    private let isMock: Bool
    
    // Observed session state
    private(set) var currentSession: Session?
    // For mock mode: simple state
    private var mockUserID: String?
    private var mockIsAuthenticated: Bool = false
    
    init(url: URL, key: String) {
        // Detect if we should run in Mock mode because keys are placeholder
        let isPlaceholder = url.absoluteString.contains("your-project-id") || key == "your-public-anon-key" || key.isEmpty
        
        if isPlaceholder {
            self.isMock = true
            self.client = nil
            print("📒 Supabase Auth: Running in MOCK Mode (Credentials are placeholders)")
        } else {
            self.isMock = false
            let client = SupabaseClient(supabaseURL: url, supabaseKey: key)
            self.client = client
            self.currentSession = client.auth.currentSession
            
            // Listen to auth state changes reactively
            Task { [weak self] in
                guard let self = self else { return }
                for await (_, session) in client.auth.authStateChanges {
                    self.currentSession = session
                }
            }
            print("✅ Supabase Auth: Initialized live client")
        }
    }
    
    var currentUserID: String? {
        if isMock {
            return mockUserID
        }
        return currentSession?.user.id.uuidString
    }
    
    var isAuthenticated: Bool {
        if isMock {
            return mockIsAuthenticated
        }
        return currentSession != nil
    }
    
    func signInWithApple() async throws {
        if isMock {
            try await simulateMockSignIn(provider: "Apple")
            return
        }
        
        // In a real implementation, get Apple token via AuthenticationServices and sign in:
        // let response = try await client?.auth.signInWithIdToken(provider: .apple, idToken: "...")
        print("Apple Sign-In triggered on Live Client")
    }
    
    func signInWithGoogle() async throws {
        if isMock {
            try await simulateMockSignIn(provider: "Google")
            return
        }
        
        // Similar to Apple, retrieve Google ID token and call signInWithIdToken
        print("Google Sign-In triggered on Live Client")
    }
    
    func signOut() async throws {
        print("📒 Supabase Auth: Signing out...")
        if isMock {
            self.mockIsAuthenticated = false
            self.mockUserID = nil
            print("📒 Supabase Auth: Mock user signed out")
            return
        }
        
        try await client?.auth.signOut()
    }
    
    private func simulateMockSignIn(provider: String) async throws {
        print("📒 Supabase Auth: Simulating \(provider) Sign-In...")
        // Add a small delay for premium feels
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        self.mockUserID = "00000000-0000-0000-0000-000000000001"
        self.mockIsAuthenticated = true
        print("✅ Supabase Auth: Mock user signed in successfully")
    }
}
