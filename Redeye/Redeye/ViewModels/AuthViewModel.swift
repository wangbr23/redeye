import AuthenticationServices
import Foundation

@Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var isSignUp = false
    var isLoading = false
    var errorMessage: String?

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && password.count >= 6
    }

    func submit() async {
        isLoading = true
        errorMessage = nil

        do {
            if isSignUp {
                try await authService.signUpWithEmail(email: email, password: password)
            } else {
                try await authService.signInWithEmail(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signInWithApple(_ credential: ASAuthorizationAppleIDCredential) async {
        isLoading = true
        errorMessage = nil

        do {
            try await authService.signInWithApple(credential: credential)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
