import Foundation
import SwiftData

@Model
final class Expense {
    var amountPaise: Int
    var note: String
    var spentAt: Date

    /// Essentials never break a streak. Groceries, health, transport, bills —
    /// without this the metric rewards skipping a meal, which is the one way
    /// a no-spend streak can do real harm.
    var isEssential: Bool

    /// nil means I paid. Otherwise the person who fronted it.
    var payer: Person?

    @Relationship(deleteRule: .cascade, inverse: \Share.expense)
    var shares: [Share]

    init(
        amountPaise: Int,
        note: String,
        spentAt: Date = .now,
        isEssential: Bool = false,
        payer: Person? = nil,
        shares: [Share] = []
    ) {
        self.amountPaise = amountPaise
        self.note = note
        self.spentAt = spentAt
        self.isEssential = isEssential
        self.payer = payer
        self.shares = shares
    }

    var isSplit: Bool { shares.count > 1 }

    /// What this expense actually cost *me* — the number the personal ledger counts.
    /// A ₹2,448 dinner split four ways is ₹612 of my money, not ₹2,448.
    var mySharePaise: Int {
        guard !shares.isEmpty else { return amountPaise }
        return shares.first(where: { $0.person == nil })?.amountPaise ?? 0
    }
}
