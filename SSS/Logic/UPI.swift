import Foundation
import UIKit

/// NPCI deep links. This is deliberately the only way money leaves the app:
/// we hand off to a UPI app and never touch the funds, which keeps SSS a
/// personal finance manager rather than a regulated payment entity.
enum UPI {

    struct App: Identifiable {
        let name: String
        let scheme: String
        var id: String { scheme }
    }

    /// Order is the order they're offered in. `upi` is the generic handler and
    /// always last — whichever app the user has claimed it.
    static let known: [App] = [
        App(name: "Google Pay", scheme: "tez"),
        App(name: "PhonePe",    scheme: "phonepe"),
        App(name: "Paytm",      scheme: "paytmmp"),
        App(name: "BHIM",       scheme: "bhim"),
    ]

    static func installed() -> [App] {
        known.filter { app in
            guard let url = URL(string: "\(app.scheme)://") else { return false }
            return UIApplication.shared.canOpenURL(url)
        }
    }

    /// Builds `upi://pay?...`, or the same query against a specific app's scheme.
    /// Amounts always carry two decimals — the spec expects `840.00`, not `840`.
    static func payURL(
        scheme: String = "upi",
        vpa: String,
        payeeName: String,
        paise: Int,
        note: String,
        reference: String
    ) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "pay"
        components.queryItems = [
            URLQueryItem(name: "pa", value: vpa),
            URLQueryItem(name: "pn", value: payeeName),
            URLQueryItem(name: "am", value: String(format: "%.2f", Double(paise) / 100)),
            URLQueryItem(name: "cu", value: "INR"),
            URLQueryItem(name: "tn", value: String(note.prefix(40))),
            URLQueryItem(name: "tr", value: reference),
        ]
        return components.url
    }

    /// A plain-text nudge to send over whatever messenger they already use.
    /// No links, no install required at the other end.
    static func reminderText(name: String, paise: Int, reason: String) -> String {
        "Hi \(name) — \(Money.rupees(paise)) still pending from \(reason). No rush, just so it's not forgotten."
    }
}
