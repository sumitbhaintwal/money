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

/// One payment that squares part of a trip. `nil` on either side is me.
struct Transfer: Identifiable {
    let from: Person?
    let to: Person?
    let paise: Int

    var id: String { "\(from?.id.uuidString ?? "me")→\(to?.id.uuidString ?? "me")" }
    var fromName: String { from?.name ?? "You" }
    var toName: String { to?.name ?? "You" }
    /// The rows the reader can act on themselves.
    var isMine: Bool { from == nil || to == nil }
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

    /// Who hands money to whom to make the trip square.
    ///
    /// Net positions say what the state is; this says what to do about it, which
    /// is the thing anyone actually asks at the end of a weekend. Everyone who
    /// is owed gets paid by whoever owes, largest first, so each payment clears
    /// somebody out entirely and the table is never longer than it has to be.
    ///
    /// Not the provably shortest list — that is NP-hard — but it can never
    /// exceed one payment fewer than there are people, which for a trip is the
    /// difference between a table you can read and a table you cannot.
    static func settleUp(in group: ExpenseGroup) -> [Transfer] {
        let balances = settlement(in: group)

        // Biggest first, name breaking ties, so the same trip produces the same
        // table twice running rather than reshuffling between renders.
        func ordered(_ rows: [GroupBalance]) -> [(who: GroupBalance, left: Int)] {
            rows.map { (who: $0, left: abs($0.paise)) }
                .sorted {
                    $0.left == $1.left
                        ? $0.who.name.localizedStandardCompare($1.who.name) == .orderedAscending
                        : $0.left > $1.left
                }
        }

        var credits = ordered(balances.filter { $0.paise > 0 })
        var debits = ordered(balances.filter { $0.paise < 0 })

        var transfers: [Transfer] = []
        var creditor = 0
        var debtor = 0

        // The two sides balance, so this drains both together. It is written to
        // stop when either runs out anyway: removing someone writes off their
        // share, which can leave a trip that no longer sums to zero.
        while debtor < debits.count && creditor < credits.count {
            let amount = min(debits[debtor].left, credits[creditor].left)
            guard amount > 0 else { break }

            transfers.append(Transfer(
                from: debits[debtor].who.person,
                to: credits[creditor].who.person,
                paise: amount
            ))

            debits[debtor].left -= amount
            credits[creditor].left -= amount
            if debits[debtor].left == 0 { debtor += 1 }
            if credits[creditor].left == 0 { creditor += 1 }
        }

        return transfers
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
