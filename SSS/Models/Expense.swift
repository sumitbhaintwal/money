import Foundation
import SwiftData

@Model
final class Expense {
    var amountPaise: Int
    var note: String
    var spentAt: Date

    /// Groceries, health, transport, bills — money that was never really a
    /// choice. Separates spending you decided on from spending you didn't.
    var isEssential: Bool

    /// nil means I paid. Otherwise the person who fronted it.
    var payer: Person?

    /// The trip or outing this belongs to, if any.
    var group: ExpenseGroup?

    @Relationship(deleteRule: .cascade, inverse: \Share.expense)
    var shares: [Share]

    init(
        amountPaise: Int,
        note: String,
        spentAt: Date = .now,
        isEssential: Bool = false,
        payer: Person? = nil,
        group: ExpenseGroup? = nil,
        shares: [Share] = []
    ) {
        self.amountPaise = amountPaise
        self.note = note
        self.spentAt = spentAt
        self.isEssential = isEssential
        self.payer = payer
        self.group = group
        self.shares = shares
    }

    /// Somebody other than me has a portion. Not `shares.count > 1`: covering a
    /// friend's ₹500 entirely is one share, and still very much a split.
    var isSplit: Bool { shares.contains { $0.person != nil } }

    /// I paid and took no portion — the whole bill was for other people, so it
    /// is money owed to me rather than money I spent.
    var excludesMe: Bool { !shares.isEmpty && !shares.contains { $0.person == nil } }

    /// How many ways it was actually divided.
    var splitWays: Int { shares.count }

    /// What this expense actually cost *me* — the number the personal ledger counts.
    /// A ₹2,448 dinner split four ways is ₹612 of my money, not ₹2,448.
    var mySharePaise: Int {
        guard !shares.isEmpty else { return amountPaise }
        return shares.first(where: { $0.person == nil })?.amountPaise ?? 0
    }
}
