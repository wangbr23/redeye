import SwiftUI

struct AuthGateView: View {
    let authService: AuthService

    var body: some View {
        if authService.isAuthenticated, let userId = authService.currentUserId {
            ContentView(userId: userId)
        } else {
            LoginView(viewModel: AuthViewModel(authService: authService))
        }
    }
}

private struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    header
                    emailPasswordForm
                    submitButton
                    divider
                    appleSignIn
                    toggleModeButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }
            .navigationBarTitleDisplayMode(.inline)
            .disabled(viewModel.isLoading)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Redeye")
                .font(.largeTitle.bold())

            Text(viewModel.isSignUp ? "Create your account" : "Welcome back")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emailPasswordForm: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .onSubmit { focusedField = .password }
                .padding()
                .background(.fill.tertiary, in: .rect(cornerRadius: 10))

            SecureField("Password", text: $viewModel.password)
                .textContentType(viewModel.isSignUp ? .newPassword : .password)
                .focused($focusedField, equals: .password)
                .onSubmit {
                    guard viewModel.isFormValid else { return }
                    Task { await viewModel.submit() }
                }
                .padding()
                .background(.fill.tertiary, in: .rect(cornerRadius: 10))

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var submitButton: some View {
        Button {
            Task { await viewModel.submit() }
        } label: {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text(viewModel.isSignUp ? "Sign Up" : "Sign In")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.isFormValid)
    }

    private var divider: some View {
        HStack {
            Rectangle().frame(height: 1).foregroundStyle(.separator)
            Text("or")
                .font(.caption)
                .foregroundStyle(.secondary)
            Rectangle().frame(height: 1).foregroundStyle(.separator)
        }
    }

    private var appleSignIn: some View {
        AppleSignInButton { credential in
            Task { await viewModel.signInWithApple(credential) }
        } onError: { error in
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private var toggleModeButton: some View {
        Button {
            viewModel.isSignUp.toggle()
            viewModel.errorMessage = nil
        } label: {
            if viewModel.isSignUp {
                Text("Already have an account? **Sign In**")
            } else {
                Text("Don't have an account? **Sign Up**")
            }
        }
        .font(.footnote)
    }
}
