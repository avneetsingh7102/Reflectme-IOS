import Foundation

/// Identity / session management.
///
/// The provider-specific UI (`SignInWithAppleButton`, Google's SDK) lives in
/// `LoginView` because it needs UIKit presenters. Those views collect the
/// provider's ID token and hand it to the service, which exchanges it for
/// a Supabase session.
@MainActor
protocol AuthService: Sendable {
    /// `true` while a Supabase session exists. SwiftUI-observable.
    var isAuthenticated: Bool { get }

    /// Stable `auth.users.id` for the signed-in user, or `nil` if logged out.
    var currentUserID: String? { get }

    /// Exchange Apple's identity token (plus the original raw nonce we sent in
    /// the request) for a Supabase session.
    func signInWithApple(idToken: String, nonce: String) async throws

    /// Exchange Google's ID token (and optionally the access token) for a
    /// Supabase session.
    func signInWithGoogle(idToken: String, accessToken: String?) async throws

    /// Terminate the current session.
    func signOut() async throws
}
