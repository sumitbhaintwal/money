import Foundation

/// Rupee formatting. Amounts are stored as paise (Int) everywhere — a ledger
/// that disagrees with itself by ₹0.01 loses trust faster than a missing feature.
enum Money {

    /// Indian digit grouping: last three digits, then pairs.
    /// 120000 -> "1,20,000"   2448 -> "2,448"   840 -> "840"
    static func grouped(_ value: Int) -> String {
        let negative = value < 0
        var digits = String(abs(value))

        if digits.count > 3 {
            let last3 = String(digits.suffix(3))
            var rest = String(digits.dropLast(3))
            var pairs: [String] = []
            while rest.count > 2 {
                pairs.insert(String(rest.suffix(2)), at: 0)
                rest = String(rest.dropLast(2))
            }
            if !rest.isEmpty { pairs.insert(rest, at: 0) }
            digits = pairs.joined(separator: ",") + "," + last3
        }

        return (negative ? "-" : "") + digits
    }

    /// Paise -> "₹2,448". Whole rupees only; we never take fractional input.
    static func rupees(_ paise: Int) -> String {
        "₹" + grouped(paise / 100)
    }

    /// Paise -> "+₹1,132" / "-₹320". Used for balances, where direction matters.
    static func signedRupees(_ paise: Int) -> String {
        let sign = paise < 0 ? "-" : "+"
        return sign + "₹" + grouped(abs(paise) / 100)
    }
}
