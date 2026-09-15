import Foundation
import SwiftData

/// What one person owes me, or I owe them, net of everything settled.
struct PersonBalance: Identifiable {
    let person: Person
    /// Positive: they owe me. Negative: I owe them.
    let paise: Int
    let notes: [String]
    let oldest: Date?

    var id: PersistentIdentifier { person.persistentModelID }
    var theyOweMe: Bool { paise > 0 }

    var reason: String {
        var parts = Array(Set(notes)).sorted().prefix(2).joined(separator: ", ")
        if parts.isEmpty { parts = "shared expenses" }
        guard let oldest else { return parts }
        let days = Ledger.calendar.dateComponents([.day], from: oldest, to: .now).day ?? 0
        switch days {
        case 0:  return "\(parts) · today"
        case 1:  return "\(parts) · 1 day"
        default: return "\(parts) · \(days) days"
        }
    }
}

enum Balances {

    static func all(in expenses: [Expense]) -> [PersonBalance] {
        var running: [PersistentIdentifier: (person: Person, paise: Int, notes: [String], oldest: Date?)] = [:]

        func add(_ person: Person, _ paise: Int, _ note: String, _ date: Date) {
            let key = person.persistentModelID
            var entry = running[key] ?? (person, 0, [], nil)
            entry.paise += paise
            entry.notes.append(note.isEmpty ? "shared expense" : note)
            entry.oldest = min(entry.oldest ?? date, date)
            running[key] = entry
        }

        for expense in expenses {
            if expense.payer == nil {
                // I fronted it — everyone else's unsettled share is owed to me.
                for share in expense.shares where share.isOutstanding {
                    guard let person = share.person else { continue }
                    add(person, share.amountPaise, expense.note, expense.spentAt)
                }
            } else if let payer = expense.payer,
                      let mine = expense.shares.first(where: { $0.person == nil }),
                      mine.settledAt == nil {
                // They fronted it — my share is owed to them.
                add(payer, -mine.amountPaise, expense.note, expense.spentAt)
            }
        }

        return running.values
            .filter { $0.paise != 0 && $0.person.isActive }
            .map { PersonBalance(person: $0.person, paise: $0.paise, notes: $0.notes, oldest: $0.oldest) }
            // Name breaks the tie: two people owing the same amount came out of
            // the dictionary in a different order each time, so the list — and
            // every export of it — reshuffled itself between renders.
            .sorted {
                abs($0.paise) == abs($1.paise)
                    ? $0.person.name.localizedStandardCompare($1.person.name) == .orderedAscending
                    : abs($0.paise) > abs($1.paise)
            }
    }

    /// Everything still open between me and one person, in both directions.
    static func openShares(with person: Person, in expenses: [Expense]) -> [Share] {
        expenses.flatMap { expense -> [Share] in
            if expense.payer == nil {
                return expense.shares.filter { $0.person?.persistentModelID == person.persistentModelID && $0.settledAt == nil }
            }
            guard expense.payer?.persistentModelID == person.persistentModelID else { return [] }
            return expense.shares.filter { $0.person == nil && $0.settledAt == nil }
        }
    }

    static func settle(with person: Person, in expenses: [Expense], on date: Date = .now) {
        for share in openShares(with: person, in: expenses) {
            share.settledAt = date
        }
    }
}


extension Balances {

    /// Has this person ever been part of an expense? Determines whether they
    /// can be deleted outright or only removed.
    static func appearsAnywhere(_ person: Person, in expenses: [Expense]) -> Bool {
        let id = person.persistentModelID
        return expenses.contains { expense in
            expense.payer?.persistentModelID == id
                || expense.shares.contains { $0.person?.persistentModelID == id }
        }
    }

    /// Removing someone writes off whatever is open between you — there is
    /// nobody left to chase or to pay.
    ///
    /// If they have ever been in a split this is a *soft* removal. Deleting the
    /// row would nullify Share.person, and a share with no person reads as
    /// mine, so their portion would quietly become my spending. Their shares
    /// keep their amounts, so no expense total moves.
    static func remove(
        _ person: Person,
        in expenses: [Expense],
        context: ModelContext,
        now: Date = .now
    ) {
        settle(with: person, in: expenses, on: now)
        person.groups.removeAll()

        if appearsAnywhere(person, in: expenses) {
            person.removedAt = now
        } else {
            context.delete(person)
        }
    }
}
