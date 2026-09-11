import Foundation

enum AppConfig {
    /// Set per build configuration via the API_BASE_URL build setting, which
    /// Info.plist forwards. Debug points at a local `wrangler dev`.
    static let apiBaseURL: URL = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
        if let url = URL(string: raw), url.scheme != nil {
            return url
        }
        assertionFailure("API_BASE_URL is missing or malformed: \(raw)")
        return URL(string: "http://127.0.0.1:8787")!
    }()
}
