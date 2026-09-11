import Foundation

struct Account: Codable, Equatable {
    var phone: String       // 10 digits, no country code
    var email: String
    var token: String

    var displayPhone: String {
        guard phone.count == 10 else { return phone }
        let a = phone.prefix(5), b = phone.suffix(5)
        return "+91 \(a) \(b)"
    }
}

/// A code has been sent and is waiting to be entered.
struct Challenge: Equatable {
    let id: String
    let phone: String
    let email: String
    let sentAt: Date
}

enum AuthError: LocalizedError {
    case badCode
    case sendFailed

    var errorDescription: String? {
        switch self {
        case .badCode:    return "That code doesn't match. Check the last message and try again."
        case .sendFailed: return "Couldn't send the code. Check your connection and try again."
        }
    }
}

protocol AuthService: Sendable {
    /// Sends one code to both the phone and the inbox.
    func sendCode(phone: String, email: String) async throws -> Challenge
    func verify(_ challenge: Challenge, code: String) async throws -> Account
}

/// Stands in until the backend exists. Accepts any six digits.
///
/// Everything real lives behind `AuthService`, so replacing this with an HTTP
/// client touches this file and nothing else.
struct StubAuthService: AuthService {
    func sendCode(phone: String, email: String) async throws -> Challenge {
        try await Task.sleep(for: .milliseconds(700))
        return Challenge(id: UUID().uuidString, phone: phone, email: email, sentAt: .now)
    }

    func verify(_ challenge: Challenge, code: String) async throws -> Account {
        try await Task.sleep(for: .milliseconds(600))
        guard code.count == 6, code.allSatisfy(\.isNumber) else { throw AuthError.badCode }
        return Account(phone: challenge.phone, email: challenge.email, token: "stub-\(challenge.id)")
    }
}

enum Validate {
    /// India only for now — the sign-in screen hard-codes the +91 prefix, so
    /// this needs generalising alongside it if the app ever ships elsewhere.
    static func phone(_ digits: String) -> Bool {
        digits.count == 10 && digits.allSatisfy(\.isNumber) && !digits.hasPrefix("0")
    }

    static func email(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard let at = t.firstIndex(of: "@"), t.lastIndex(of: "@") == at else { return false }
        let name = t[t.startIndex..<at]
        let host = t[t.index(after: at)...]
        return !name.isEmpty
            && host.contains(".")
            && !host.hasPrefix(".")
            && !host.hasSuffix(".")
            && !t.contains(" ")
    }

    static func digitsOnly(_ text: String, max: Int) -> String {
        String(text.filter(\.isNumber).prefix(max))
    }
}

@Observable
final class SessionStore {
    private(set) var account: Account?

    var isSignedIn: Bool { account != nil }

    private let key = "sss.account"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(Account.self, from: data) {
            account = saved
        }
    }

    // The token belongs in the Keychain once it is a real one. UserDefaults is
    // fine only because the stub's token grants nothing.
    func signIn(_ account: Account) {
        self.account = account
        if let data = try? JSONEncoder().encode(account) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func signOut() {
        account = nil
        UserDefaults.standard.removeObject(forKey: key)
    }
}
