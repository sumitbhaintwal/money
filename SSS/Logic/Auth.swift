import Foundation
import Observation

struct Account: Codable, Equatable {
    var id: String
    var phone: String      // 10 digits, no country code
    var email: String

    var displayPhone: String {
        guard phone.count == 10 else { return phone }
        return "+91 \(phone.prefix(5)) \(phone.suffix(5))"
    }
}

/// A code has been sent and is waiting to be entered.
struct Challenge: Equatable {
    let id: String
    let phone: String
    let email: String
    let expiresAt: Date
}

struct AuthError: LocalizedError, Equatable {
    let code: String
    let message: String
    var errorDescription: String? { message }

    static let offline = AuthError(
        code: "offline",
        message: "Couldn't reach the server. Check your connection and try again."
    )
    static let unexpected = AuthError(
        code: "unexpected",
        message: "Something went wrong. Try again in a moment."
    )
}

protocol AuthService: Sendable {
    /// Both are required. Only the email receives the code — SMS to Indian
    /// numbers needs DLT registration, so the phone is recorded, not messaged.
    func sendCode(phone: String, email: String) async throws -> Challenge
    func verify(_ challenge: Challenge, code: String) async throws -> (token: String, account: Account)
    func me(token: String) async throws -> Account
    func signOut(token: String) async
}

/// The shape every non-2xx response from the backend uses.
private struct ServerFailure: Decodable {
    let error: String
    let message: String?
}

// MARK: - The real one

struct HTTPAuthService: AuthService {
    var baseURL: URL = AppConfig.apiBaseURL

    func sendCode(phone: String, email: String) async throws -> Challenge {
        struct Response: Decodable {
            let challengeId: String
            let expiresAt: Double
        }
        let body = try await post("/v1/auth/start", ["phone": phone, "email": email], as: Response.self)
        return Challenge(
            id: body.challengeId,
            phone: phone,
            email: email,
            expiresAt: Date(timeIntervalSince1970: body.expiresAt)
        )
    }

    func verify(_ challenge: Challenge, code: String) async throws -> (token: String, account: Account) {
        struct Response: Decodable {
            let token: String
            let account: Account
        }
        let body = try await post(
            "/v1/auth/verify",
            ["challengeId": challenge.id, "code": code],
            as: Response.self
        )
        return (body.token, body.account)
    }

    func me(token: String) async throws -> Account {
        struct Response: Decodable { let account: Account }
        var request = URLRequest(url: baseURL.appending(path: "/v1/me"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await send(request, as: Response.self).account
    }

    /// Best effort. The local session is cleared either way — a server we
    /// cannot reach must not trap someone in a signed-in state.
    func signOut(token: String) async {
        var request = URLRequest(url: baseURL.appending(path: "/v1/me/signout"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: Plumbing

    private func post<T: Decodable>(_ path: String, _ payload: [String: String], as: T.Type) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return try await send(request, as: T.self)
    }

    private func send<T: Decodable>(_ request: URLRequest, as: T.Type) async throws -> T {
        var request = request
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.offline
        }

        guard let http = response as? HTTPURLResponse else { throw AuthError.unexpected }

        guard (200..<300).contains(http.statusCode) else {
            // The server sends a message written for a person; prefer it over
            // anything this client could invent.
            if let failure = try? JSONDecoder().decode(ServerFailure.self, from: data) {
                throw AuthError(
                    code: failure.error,
                    message: failure.message ?? AuthError.unexpected.message
                )
            }
            throw AuthError.unexpected
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AuthError.unexpected
        }
    }
}

// MARK: - Session

@Observable
@MainActor
final class SessionStore {
    private(set) var account: Account?

    var isSignedIn: Bool { account != nil && token != nil }

    private let accountKey = "sss.account"
    private let tokenKey = "sss.token"
    private let auth: AuthService

    /// Never written to disk outside the Keychain.
    private var token: String? {
        get { Keychain.get(tokenKey) }
        set {
            if let newValue { Keychain.set(newValue, for: tokenKey) }
            else { Keychain.remove(tokenKey) }
        }
    }

    init(auth: AuthService = HTTPAuthService()) {
        self.auth = auth
        if let data = UserDefaults.standard.data(forKey: accountKey),
           let saved = try? JSONDecoder().decode(Account.self, from: data),
           Keychain.get(tokenKey) != nil {
            account = saved
        }
    }

    func signIn(token: String, account: Account) {
        self.token = token
        self.account = account
        if let data = try? JSONEncoder().encode(account) {
            UserDefaults.standard.set(data, forKey: accountKey)
        }
    }

    /// Revokes the token server-side, so signing out on this phone genuinely
    /// ends the session rather than only forgetting it here.
    func signOut() async {
        if let token { await auth.signOut(token: token) }
        clearLocally()
    }

    /// Confirms the stored token is still good. A token revoked elsewhere would
    /// otherwise leave the app looking signed in until the next request failed.
    func refresh() async {
        guard let token else { return }
        do {
            let fresh = try await auth.me(token: token)
            signIn(token: token, account: fresh)
        } catch let error as AuthError where error.code == "unauthorized" {
            clearLocally()
        } catch {
            // Offline or a server blip is not a reason to sign someone out.
        }
    }

    private func clearLocally() {
        token = nil
        account = nil
        UserDefaults.standard.removeObject(forKey: accountKey)
    }
}

// MARK: - Validation

enum Validate {
    /// India only — the sign-in screen hard-codes +91, and the server enforces
    /// the same rule. Generalising means changing all three together.
    static func phone(_ digits: String) -> Bool {
        digits.count == 10 && digits.allSatisfy(\.isNumber) && !digits.hasPrefix("0")
    }

    static func email(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespaces)
        guard let at = value.firstIndex(of: "@"), value.lastIndex(of: "@") == at else { return false }
        let name = value[value.startIndex..<at]
        let host = value[value.index(after: at)...]
        return !name.isEmpty
            && host.contains(".")
            && !host.hasPrefix(".")
            && !host.hasSuffix(".")
            && !value.contains(" ")
    }

    static func digitsOnly(_ text: String, max: Int) -> String {
        String(text.filter(\.isNumber).prefix(max))
    }
}
