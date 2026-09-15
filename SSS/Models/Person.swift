import Foundation
import SwiftData

@Model
final class Person: Syncable {
    @Attribute(.unique) var id: UUID = UUID()

    var name: String
    var upiID: String?
    var createdAt: Date

    /// Removing someone is a soft removal, never a delete, whenever they have
    /// ever been in a split. Deleting the row would nullify Share.person, and
    /// a share with no person reads as *mine* — their portion would silently
    /// become my spending and the debt would vanish.
    ///
    /// Distinct from `deletedAt`, which means the row itself is gone: someone
    /// who was never in a split gets that instead.
    var removedAt: Date?

    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var syncedUpdatedAt: Date?

    var groups: [ExpenseGroup] = []

    init(name: String, upiID: String? = nil, createdAt: Date = .now, id: UUID = UUID()) {
        self.id = id
        self.name = name
        self.upiID = upiID
        self.createdAt = createdAt
        self.updatedAt = Millis.round(createdAt)
    }

    var initial: String { String(name.prefix(1)) }
    var isActive: Bool { removedAt == nil }
}
