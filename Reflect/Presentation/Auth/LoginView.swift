import SwiftUI
import AuthenticationServices
import CryptoKit

/// Pre-auth screen. Runs the system Apple-Sign-In UI, generates the nonce
/// pair Supabase requires for ID-token exchange, and hands the resulting
/// idToken+rawNonce to `AuthService`.
///
/// Google sign-in is intentionally a stub: enabling it requires the
/// GoogleSignIn SPM package + a Google Cloud OAuth client ID. The button is
/// shown but disabled until that's configured.
struct LoginView: View {
    @State private var viewModel: LoginViewModel

    init(authService: any AuthService) {
        _viewModel = State(initialValue: LoginViewModel(authService: authService))
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 56))
                    .foregroundStyle(ReflectTheme.accent)

                Text("Reflect")
                    .font(ReflectTheme.serif(36, weight: .bold))
                    .foregroundStyle(ReflectTheme.textPrimary)

                Text("Your spoken thoughts, mapped.")
                    .font(ReflectTheme.rounded(15))
                    .foregroundStyle(ReflectTheme.textMuted)
            }

            Spacer()

            VStack(spacing: 14) {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(ReflectTheme.rounded(12))
                        .foregroundStyle(.red.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .tint(ReflectTheme.accent)
                        .scaleEffect(1.1)
                        .frame(height: 50)
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        viewModel.prepareAppleRequest(request)
                    } onCompletion: { result in
                        viewModel.handleAppleCompletion(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .cornerRadius(12)

                    Button { viewModel.signInWithGoogle() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 18))
                            Text("Sign in with Google")
                                .font(ReflectTheme.rounded(15, weight: .semibold))
                            Spacer().frame(width: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(ReflectTheme.textPrimary.opacity(0.4))
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(ReflectTheme.separator, lineWidth: 1)
                                )
                        )
                    }
                    .disabled(true)
                    .overlay(alignment: .trailing) {
                        Text("soon")
                            .font(ReflectTheme.rounded(10, weight: .bold))
                            .foregroundStyle(ReflectTheme.textMuted)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(ReflectTheme.separator))
                            .padding(.trailing, 12)
                    }
                }

                Text("By continuing you agree to our terms.")
                    .font(ReflectTheme.rounded(11))
                    .foregroundStyle(ReflectTheme.textMuted.opacity(0.7))
                    .padding(.top, 6)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 64)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReflectTheme.canvas.ignoresSafeArea())
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class LoginViewModel {
    private let authService: any AuthService

    var isLoading = false
    var errorMessage: String?

    /// Raw nonce we sent in the Apple request — we hand this back to Supabase
    /// so it can verify the hashed nonce baked into the returned ID token.
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
            // User cancellation is the most common path — treat silently.
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
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

    // MARK: Nonce helpers

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        if status != errSecSuccess {
            // Fall back to UUIDs concatenated if the secure RNG ever fails.
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
