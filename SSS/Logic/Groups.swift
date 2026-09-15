import Foundation
import SwiftData

/// Where one person stands on a trip. `person` nil is me.
///
/// Positive means they are owed that much; negative means they owe it. Across a
/// whole trip these sum to zero, which is the quickest check that the maths is
/// right.
struct GroupBalance: Identifiable {
    let person: Person?
    let paise: Int

    /// The person's own UUID, not their PersistentIdentifier: `storeIdentifier`
    /// names the *store*, so every row shared one id and ForEach rendered the
    /// same person three times over three different balances.
    var id: String { person?.id.uuidString ?? "me" }
    var isMine: Bool { person == nil }
    var name: String { person?.name ?? "You" }
    var isOwed: Bool { paise > 0 }
}

enum Groups {

    /// Everything spent on the trip, whoever paid — the number people mean when
    /// they ask what a weekend cost.
    static func totalPaise(_ group: ExpenseGroup) -> Int {
        group.expenses.reduce(0) { $0 + $1.amountPaise }
    }

    /// The part of that which was mine.
    static func mySharePaise(_ group: ExpenseGroup) -> Int {
        group.expenses.reduce(0) { $0 + $1.mySharePaise }
    }

    /// Where everyone on the trip stands, me included.
    ///
    /// A trip is the one place this app has to account for money that is not
    /// mine. Ravi owing Priya is none of my business on the People tab — it is
    /// not my money and it must never move my totals — but on a trip it is most
    /// of the point. Reading it off my own shares, as the personal ledger does,
    /// gave a settlement for a ₹1,200 dinner Priya paid that mentioned only my
    /// ₹400 and left the other two with nothing to go on.
    ///
    /// Everyone owes the person who paid their share of it. The payer's own
    /// share is not a debt to themselves, so it drops out, and what is left is
    /// each person's net position.
    static func settlement(in group: ExpenseGroup) -> [GroupBalance] {
        var net: [Party: Int] = [:]
        var known: [Party: Person] = [:]

        for expense in group.expenses {
            let payer = Party(expense.payer)
            if let person = expense.payer { known[payer] = person }

            for share in expense.shares where share.settledAt == nil {
                let debtor = Party(share.person)
                // Paying for your own portion settles nothing.
                guard debtor != payer else { continue }
                if let person = share.person { known[debtor] = person }

                net[debtor, default: 0] -= share.amountPaise
                net[payer, default: 0] += share.amountPaise
            }
        }

        return net.compactMap { party, paise -> GroupBalance? in
            guard paise != 0 else { return nil }
            guard case .person = party else { return GroupBalance(person: nil, paise: paise) }
            // Removing someone writes off what was open with them, so they stop
            // appearing here for the same reason they stop appearing elsewhere.
            guard let person = known[party], person.isActive else { return nil }
            return GroupBalance(person: person, paise: paise)
        }
        // Owed at the top, owing at the bottom, so the list reads as a
        // settlement rather than an unordered pile.
        .sorted {
            $0.paise == $1.paise
                ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                : $0.paise > $1.paise
        }
    }

    /// My position on the trip alone: positive means the trip owes me.
    static func netPaise(in group: ExpenseGroup) -> Int {
        settlement(in: group).first(where: \.isMine)?.paise ?? 0
    }

    static func sorted(_ groups: [ExpenseGroup]) -> [ExpenseGroup] {
        groups.sorted { a, b in
            if a.isOpen != b.isOpen { return a.isOpen }      // open trips first
            return a.createdAt > b.createdAt
        }
    }

    /// Me, or somebody else. Shares and payers both use nil for me, so they need
    /// one key type to be added up against each other.
    private enum Party: Hashable {
        case me
        case person(PersistentIdentifier)

        init(_ person: Person?) {
            self = person.map { .person($0.persistentModelID) } ?? .me
        }
    }
}
