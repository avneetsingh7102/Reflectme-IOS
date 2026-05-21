import SwiftUI
import AuthenticationServices
import CryptoKit

/// Pre-auth screen following the Reflect Mobile design.
///
/// Layout (top → bottom):
/// 1. **Mark**: a resting `PulsingRing` (68pt) acting as the brand glyph.
/// 2. **Eyebrow + serif headline**: "A quiet place for your *thoughts*".
/// 3. **Sub-copy**: short serif paragraph.
/// 4. **Two CTAs**: Apple (dark blue, white text) and Google (white, separator).
/// 5. **Tiny terms line**.
///
/// The Apple flow generates a cryptographic nonce client-side, hands the
/// hashed nonce to AuthenticationServices, then exchanges the returned ID
/// token + raw nonce with Supabase via `AuthService.signInWithApple`.
struct LoginView: View {
    @State private var viewModel: LoginViewModel

    init(authService: any AuthService) {
        _viewModel = State(initialValue: LoginViewModel(authService: authService))
    }

    var body: some View {
        ZStack {
            ReflectTheme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                mark
                copyBlock
                Spacer(minLength: 0)
                authBlock
            }
            .padding(.horizontal, ReflectTheme.spacingXL - 4)

            if viewModel.isLoading {
                loadingOverlay
            }
        }
    }

    // MARK: - Blocks

    private var mark: some View {
        PulsingRing(mode: .resting, size: 68)
            .padding(.bottom, 28)
    }

    private var copyBlock: some View {
        VStack(spacing: 14) {
            Text("Reflect · voice journal")
                .eyebrowStyle()

            (Text("A quiet place\nfor your ")
                .foregroundStyle(ReflectTheme.ink)
            + Text("thoughts").italic().foregroundStyle(ReflectTheme.blue500)
            + Text(".").foregroundStyle(ReflectTheme.ink))
                .font(.system(size: 34, weight: .medium, design: .serif))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text("Speak freely. We’ll listen, transcribe, and connect your reflections over time.")
                .font(ReflectTheme.serif(16))
                .foregroundStyle(ReflectTheme.inkSoft)
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
    }

    private var authBlock: some View {
        VStack(spacing: 12) {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(ReflectTheme.rounded(12))
                    .foregroundStyle(.red.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            SignInWithAppleButton(.signIn) { request in
                viewModel.prepareAppleRequest(request)
            } onCompletion: { result in
                viewModel.handleAppleCompletion(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .clipShape(Capsule())

            Button { viewModel.signInWithGoogle() } label: {
                HStack(spacing: 10) {
                    googleGlyph
                    Text("Continue with Google")
                        .font(ReflectTheme.rounded(15, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(ReflectTheme.ink)
                .background(
                    Capsule()
                        .fill(Color.white)
                        .overlay(Capsule().stroke(ReflectTheme.separator, lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            .opacity(0.55)
            .disabled(true)
            .overlay(alignment: .trailing) {
                Text("soon")
                    .font(ReflectTheme.rounded(10, weight: .bold))
                    .foregroundStyle(ReflectTheme.inkSoft)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(ReflectTheme.surface3))
                    .padding(.trailing, 14)
            }

            (Text("Your reflections are encrypted & private.\nBy continuing you agree to our ")
                .foregroundStyle(ReflectTheme.inkFaint)
            + Text("terms").foregroundStyle(ReflectTheme.blue500)
            + Text(".").foregroundStyle(ReflectTheme.inkFaint))
                .font(ReflectTheme.rounded(11.5))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 4)

            // Local-only bypass for testing without a paid Apple Developer
            // account. Cloud sync is disabled in this mode.
            Button { viewModel.signInLocally() } label: {
                Text("Skip — try locally (no sync)")
                    .font(ReflectTheme.rounded(12, weight: .semibold))
                    .foregroundStyle(ReflectTheme.inkSoft)
                    .underline()
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.bottom, ReflectTheme.spacingLG)
    }

    private var googleGlyph: some View {
        Image(systemName: "g.circle.fill")
            .font(.system(size: 18))
            .foregroundStyle(ReflectTheme.blue500)
    }

    private var loadingOverlay: some View {
        ZStack {
            ReflectTheme.canvas.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(ReflectTheme.primary)
                    .scaleEffect(1.2)
                Text("Setting up your journal…")
                    .font(ReflectTheme.rounded(13, weight: .medium))
                    .foregroundStyle(ReflectTheme.inkSoft)
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class LoginViewModel {
    private let authService: any AuthService

    var isLoading = false
    var errorMessage: String?

    /// Raw nonce sent to Apple; we hand it back to Supabase so it can validate
    /// the SHA-256 hash baked into the returned ID token.
    private var currentNonce: String?

    init(authService: any AuthService) {
        self.authService = authService
    }

    // MARK: Apple

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue { return }
            errorMessage = "Apple sign-in failed: \(error.localizedDescription)"

        case .success(let authorization):
            guard
                let appleCred = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = appleCred.identityToken,
                let token = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = "Apple returned an unexpected credential."
                return
            }
            isLoading = true
            errorMessage = nil
            Task {
                do {
                    try await authService.signInWithApple(idToken: token, nonce: nonce)
                } catch {
                    errorMessage = error.localizedDescription
                }
                currentNonce = nil
                isLoading = false
            }
        }
    }

    // MARK: Google (stub)

    func signInWithGoogle() {
        errorMessage = "Google sign-in needs the GoogleSignIn SPM package + a Google Cloud OAuth client ID. Coming soon."
    }

    // MARK: Local bypass (testing only)

    func signInLocally() {
        errorMessage = nil
        authService.signInLocally()
    }

    // MARK: Nonce helpers

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        if status != errSecSuccess {
            return UUID().uuidString + UUID().uuidString
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
