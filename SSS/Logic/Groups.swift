import Foundation

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

    /// Who owes whom, counting only this group's expenses.
    static func balances(in group: ExpenseGroup) -> [PersonBalance] {
        Balances.all(in: group.expenses)
    }

    /// Net across the group: positive means the group owes me on balance.
    static func netPaise(in group: ExpenseGroup) -> Int {
        balances(in: group).reduce(0) { $0 + $1.paise }
    }

    static func sorted(_ groups: [ExpenseGroup]) -> [ExpenseGroup] {
        groups.sorted { a, b in
            if a.isOpen != b.isOpen { return a.isOpen }      // open trips first
            return a.createdAt > b.createdAt
        }
    }
}
