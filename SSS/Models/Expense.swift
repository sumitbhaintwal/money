import Foundation
import SwiftData

@Model
final class Expense: Syncable {
    @Attribute(.unique) var id: UUID = UUID()

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

    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncedUpdatedAt: Date?

    /// Includes tombstones, which linger until the server has been told about
    /// them. Read `shares` instead; assign to this one.
    @Relationship(deleteRule: .cascade, inverse: \Share.expense)
    var storedShares: [Share]

    init(
        amountPaise: Int,
        note: String,
        spentAt: Date = .now,
        isEssential: Bool = false,
        payer: Person? = nil,
        group: ExpenseGroup? = nil,
        shares: [Share] = [],
        id: UUID = UUID(),
        updatedAt: Date = .now
    ) {
        self.id = id
        self.amountPaise = amountPaise
        self.note = note
        self.spentAt = spentAt
        self.isEssential = isEssential
        self.payer = payer
        self.group = group
        self.storedShares = shares
        self.updatedAt = Millis.round(updatedAt)
    }

    /// The shares that still count. A deleted share keeps its row until it has
    /// been pushed, and counting it would move every total in the app.
    var shares: [Share] { storedShares.filter { $0.deletedAt == nil } }

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
