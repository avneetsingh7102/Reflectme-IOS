import SwiftUI
import AuthenticationServices

@MainActor
@Observable
final class LoginViewModel {
    private let authService: any AuthService
    
    var isLoading = false
    var errorMessage: String?
    
    init(authService: any AuthService) {
        self.authService = authService
    }
    
    func signInWithApple() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                try await authService.signInWithApple()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    func signInWithGoogle() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                try await authService.signInWithGoogle()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct LoginView: View {
    @State private var viewModel: LoginViewModel
    
    init(authService: any AuthService) {
        _viewModel = State(initialValue: LoginViewModel(authService: authService))
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("Reflect")
                    .font(.system(.largeTitle, design: .serif))
                    .fontWeight(.bold)
                
                Text("Visualize your spoken thoughts.")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                // Apple Sign-In Button
                SignInWithAppleButton(.signIn) { request in
                    // Logic to configure request
                } onCompletion: { result in
                    Task { @MainActor in
                        viewModel.signInWithApple()
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(12)
                
                // Google Sign-In Button (Custom because GoogleSignIn SDK is separate)
                Button {
                    viewModel.signInWithGoogle()
                } label: {
                    HStack {
                        Image(systemName: "g.circle.fill")
                        Text("Sign in with Google")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 64)
            .disabled(viewModel.isLoading)
        }
        .background(Color(hex: "FCF9F3")) // Canvas color from ReflectTheme
    }
}

#Preview {
    LoginView(authService: SupabaseAuthService(url: URL(string: "https://example.com")!, key: ""))
}
