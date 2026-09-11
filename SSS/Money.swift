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

    /// Paise -> "380", "1.9k", "12k", "1.2L". For the month grid, where a cell
    /// is about 46pt wide and a full "₹1,850" will not fit.
    static func compact(_ paise: Int) -> String {
        let rupees = paise / 100
        func trim(_ value: Double, _ suffix: String) -> String {
            let text = String(format: "%.1f", value)
            return (text.hasSuffix(".0") ? String(text.dropLast(2)) : text) + suffix
        }
        switch rupees {
        case ..<1_000:
            // Two decimals below a thousand, so ₹100 and ₹140 stay distinct —
            // one decimal would collapse both to 0.1k.
            let k = ((Double(rupees) / 1_000) * 100).rounded() / 100
            // ₹999 rounds to 1.00k, which would read as two renderings of the
            // same value next to the branch below. Hand it over instead.
            return k >= 1 ? "1k" : String(format: "%.2f", k) + "k"
        case ..<10_000:  return trim(Double(rupees) / 1_000, "k")
        case ..<100_000: return "\(rupees / 1_000)k"
        default:         return trim(Double(rupees) / 100_000, "L")
        }
    }

    /// Paise -> "+₹1,132" / "-₹320". Used for balances, where direction matters.
    static func signedRupees(_ paise: Int) -> String {
        let sign = paise < 0 ? "-" : "+"
        return sign + "₹" + grouped(abs(paise) / 100)
    }
}
