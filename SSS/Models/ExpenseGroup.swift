import Foundation
import SwiftData

/// A trip, a flat, a weekend — a named bucket of expenses shared with the same
/// set of people. Adding an expense to a group pre-selects those people, which
/// is most of the tedium of splitting the same bill six times.
@Model
final class ExpenseGroup {
    var name: String
    var createdAt: Date
    var closedAt: Date?

    @Relationship(inverse: \Person.groups)
    var members: [Person]

    /// Nullify, not cascade: closing or deleting a trip must never delete the
    /// money that was spent on it.
    @Relationship(deleteRule: .nullify, inverse: \Expense.group)
    var expenses: [Expense]

    init(name: String, members: [Person] = [], createdAt: Date = .now) {
        self.name = name
        self.members = members
        self.createdAt = createdAt
        self.expenses = []
    }

    var isOpen: Bool { closedAt == nil }
}
