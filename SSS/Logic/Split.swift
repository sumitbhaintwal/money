import Foundation

enum Split {

    /// Even shares, in whole rupees. Paise would divide cleanly and give people
    /// amounts like ₹489.60 that nobody can hand over, so the remainder is
    /// handed to the first few participants instead of hidden in fractions.
    /// ₹2,448 across 5 -> 489, 489, 489, 490, 491 (three of them pay ₹1 more).
    static func evenly(totalPaise: Int, among count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let rupees = totalPaise / 100
        let base = rupees / count
        let remainder = rupees % count
        return (0..<count).map { index in
            (base + (index < remainder ? 1 : 0)) * 100
        }
    }

    /// How the uneven case gets explained, so the rounding is visible rather than silent.
    static func remainderNote(totalPaise: Int, among count: Int) -> String? {
        guard count > 1 else { return nil }
        let remainder = (totalPaise / 100) % count
        guard remainder > 0 else { return nil }
        let people = remainder == 1 ? "person pays" : "people pay"
        return "\(Money.rupees(totalPaise)) will not divide by \(count) — the first \(remainder) \(people) ₹1 more."
    }
}
