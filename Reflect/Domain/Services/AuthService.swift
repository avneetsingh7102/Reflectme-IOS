import Foundation

/// Identity / session management.
///
/// The provider-specific UI (`SignInWithAppleButton`, Google's SDK) lives in
/// `LoginView` because it needs UIKit presenters. Those views collect the
/// provider's ID token and hand it to the service, which exchanges it for
/// a Supabase session.
@MainActor
protocol AuthService: Sendable {
    /// `true` while a Supabase session exists OR local-bypass is active.
    /// SwiftUI-observable.
    var isAuthenticated: Bool { get }

    /// Stable `auth.users.id` for the signed-in user, or `nil` if logged out.
    /// When `isLocalBypass` is true this is a sentinel string (no real user).
    var currentUserID: String? { get }

    /// `true` when the user tapped "Skip" on the login screen. Cloud sync /
    /// pull are short-circuited in this mode so the app works fully offline
    /// without a paid Apple Developer account. Flip back to real auth by
    /// signing out and signing in with Apple or Google.
    var isLocalBypass: Bool { get }

    /// Exchange Apple's identity token (plus the original raw nonce we sent in
    /// the request) for a Supabase session.
    func signInWithApple(idToken: String, nonce: String) async throws

    /// Exchange Google's ID token (and optionally the access token) for a
    /// Supabase session.
    func signInWithGoogle(idToken: String, accessToken: String?) async throws

    /// Local-only sign in — no Supabase session, no cloud sync. Used for
    /// testing on a free Apple ID provisioning profile.
    func signInLocally()

    /// Terminate the current session (also clears local-bypass).
    func signOut() async throws
}
