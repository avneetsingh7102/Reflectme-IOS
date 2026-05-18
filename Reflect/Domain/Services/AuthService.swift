import Foundation

/// Protocol for authentication operations.
@MainActor
public protocol AuthService: Sendable {
    /// The currently authenticated user ID, if any.
    var currentUserID: String? { get }
    
    /// Whether a user is currently logged in.
    var isAuthenticated: Bool { get }
    
    /// Trigger Apple Sign-In flow.
    func signInWithApple() async throws
    
    /// Trigger Google Sign-In flow.
    func signInWithGoogle() async throws
    
    /// Sign out the current user.
    func signOut() async throws
}
