import Foundation
import AuthenticationServices
import Security

// MARK: - Auth Session

struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userId: String
}

// MARK: - Auth Errors

enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case emailTaken
    case networkError(Error)
    case serverError(String)
    case noSession
    case appleSignInFailed(String)
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailTaken:
            return "An account with this email already exists"
        case .networkError(let error):
            return error.localizedDescription
        case .serverError(let message):
            return message
        case .noSession:
            return "Not signed in"
        case .appleSignInFailed(let message):
            return message
        case .keychainError:
            return "Failed to access stored credentials"
        }
    }
}

// MARK: - Supabase Auth Response DTOs

private struct SupabaseAuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: SupabaseUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

private struct SupabaseUser: Decodable {
    let id: String
}

private struct SupabaseErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?
    let msg: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case msg
    }

    var message: String {
        errorDescription ?? msg ?? error ?? "Unknown error"
    }
}

// MARK: - Keychain

private enum KeychainHelper {
    private static let service = "com.redeye.auth"
    private static let account = "session"

    static func save(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.keychainError(status)
        }
    }

    static func load() -> AuthSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - AuthService

@Observable
final class AuthService {
    private(set) var isAuthenticated = false
    private(set) var currentUserId: String?

    private var session: AuthSession?
    private let supabaseURL: URL
    private let supabaseAnonKey: String
    private let urlSession: URLSession
    private let decoder = JSONDecoder()

    init(supabaseURL: URL, supabaseAnonKey: String, urlSession: URLSession = .shared) {
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = supabaseAnonKey
        self.urlSession = urlSession

        if let stored = KeychainHelper.load() {
            self.session = stored
            self.currentUserId = stored.userId
            self.isAuthenticated = true
        }
    }

    // MARK: - Public API

    func signInWithEmail(email: String, password: String) async throws {
        let body: [String: String] = ["email": email, "password": password]
        let response: SupabaseAuthResponse = try await authRequest(
            path: "/auth/v1/token",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            body: body
        )
        try applySession(from: response)
    }

    func signUpWithEmail(email: String, password: String) async throws {
        let body: [String: String] = ["email": email, "password": password]
        let response: SupabaseAuthResponse = try await authRequest(
            path: "/auth/v1/signup",
            body: body
        )
        try applySession(from: response)
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let identityTokenData = credential.identityToken,
              let idToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AuthError.appleSignInFailed("Missing identity token")
        }

        let body: [String: Any] = [
            "provider": "apple",
            "id_token": idToken,
        ]
        let response: SupabaseAuthResponse = try await authRequest(
            path: "/auth/v1/token",
            queryItems: [URLQueryItem(name: "grant_type", value: "id_token")],
            body: body
        )
        try applySession(from: response)
    }

    func signOut() {
        session = nil
        currentUserId = nil
        isAuthenticated = false
        KeychainHelper.delete()
    }

    func refreshTokenIfNeeded() async throws -> String {
        guard let session else { throw AuthError.noSession }

        // 30-second buffer before expiry
        if session.expiresAt.timeIntervalSinceNow > 30 {
            return session.accessToken
        }

        let body: [String: String] = ["refresh_token": session.refreshToken]
        do {
            let response: SupabaseAuthResponse = try await authRequest(
                path: "/auth/v1/token",
                queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                body: body
            )
            try applySession(from: response)
            return response.accessToken
        } catch {
            signOut()
            throw error
        }
    }

    func currentAccessToken() async throws -> String {
        try await refreshTokenIfNeeded()
    }

    // MARK: - Private

    private func applySession(from response: SupabaseAuthResponse) throws {
        let session = AuthSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)),
            userId: response.user.id
        )
        self.session = session
        self.currentUserId = session.userId
        self.isAuthenticated = true
        try KeychainHelper.save(session)
    }

    private func authRequest<T: Decodable, B: Encodable>(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: B
    ) async throws -> T {
        var components = URLComponents(url: supabaseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw AuthError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.serverError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = try? decoder.decode(SupabaseErrorResponse.self, from: data)
            let message = errorBody?.message ?? "Request failed (\(httpResponse.statusCode))"

            switch httpResponse.statusCode {
            case 400 where message.lowercased().contains("invalid"):
                throw AuthError.invalidCredentials
            case 422 where message.lowercased().contains("already registered"):
                throw AuthError.emailTaken
            case 401:
                throw AuthError.invalidCredentials
            default:
                throw AuthError.serverError(message)
            }
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AuthError.serverError("Failed to parse auth response")
        }
    }

    // Dictionary body overload for Apple Sign In (mixed value types)
    private func authRequest<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: [String: Any]
    ) async throws -> T {
        var components = URLComponents(url: supabaseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw AuthError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.serverError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = try? decoder.decode(SupabaseErrorResponse.self, from: data)
            let message = errorBody?.message ?? "Request failed (\(httpResponse.statusCode))"

            switch httpResponse.statusCode {
            case 400 where message.lowercased().contains("invalid"):
                throw AuthError.invalidCredentials
            case 422 where message.lowercased().contains("already registered"):
                throw AuthError.emailTaken
            case 401:
                throw AuthError.invalidCredentials
            default:
                throw AuthError.serverError(message)
            }
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AuthError.serverError("Failed to parse auth response")
        }
    }
}
