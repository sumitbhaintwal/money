import Foundation
import SwiftData

/// A trip, a flat, a weekend — a named bucket of expenses shared with the same
/// set of people. Adding an expense to a group pre-selects those people, which
/// is most of the tedium of splitting the same bill six times.
@Model
final class ExpenseGroup: Syncable {
    @Attribute(.unique) var id: UUID = UUID()

    var name: String
    var createdAt: Date
    var closedAt: Date?

    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncedUpdatedAt: Date?

    /// Includes tombstoned people. Read `members`; assign to this one.
    @Relationship(inverse: \Person.groups)
    var storedMembers: [Person]

    /// Nullify, not cascade: closing or deleting a trip must never delete the
    /// money that was spent on it. Includes tombstones — read `expenses`.
    @Relationship(deleteRule: .nullify, inverse: \Expense.group)
    var storedExpenses: [Expense]

    init(name: String, members: [Person] = [], createdAt: Date = .now, id: UUID = UUID()) {
        self.id = id
        self.name = name
        self.storedMembers = members
        self.createdAt = createdAt
        self.storedExpenses = []
        self.updatedAt = Millis.round(createdAt)
    }

    var members: [Person] { storedMembers.filter { $0.deletedAt == nil } }
    var expenses: [Expense] { storedExpenses.filter { $0.deletedAt == nil } }

    var isOpen: Bool { closedAt == nil }
}
