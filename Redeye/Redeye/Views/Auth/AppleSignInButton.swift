import AuthenticationServices
import SwiftUI

struct AppleSignInButton: View {
    let onCredential: (ASAuthorizationAppleIDCredential) -> Void
    let onError: (Error) -> Void

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.email, .fullName]
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                    onCredential(credential)
                }
            case .failure(let error):
                onError(error)
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
    }
}
