import Foundation
import SwiftData

@Model
final class Person {
    var name: String
    var upiID: String?
    var createdAt: Date

    /// Removing someone is a soft removal, never a delete, whenever they have
    /// ever been in a split. Deleting the row would nullify Share.person, and
    /// a share with no person reads as *mine* — their portion would silently
    /// become my spending and the debt would vanish.
    var removedAt: Date?

    var groups: [ExpenseGroup] = []

    init(name: String, upiID: String? = nil, createdAt: Date = .now) {
        self.name = name
        self.upiID = upiID
        self.createdAt = createdAt
    }

    var initial: String { String(name.prefix(1)) }
    var isActive: Bool { removedAt == nil }
}
