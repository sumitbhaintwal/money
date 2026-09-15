import Foundation

/// What every row needs to exist in two places at once.
///
/// `id` is a UUID this phone invents, not a database key, so the same expense
/// has the same identity before it has ever reached the server.
///
/// `deletedAt` is why nothing is ever really deleted: a row that is simply gone
/// is indistinguishable from one this device has not seen yet, so a delete has
/// to be a fact that can travel. Tombstones are cleared for real once the
/// server has acknowledged them.
protocol Syncable: AnyObject {
    var id: UUID { get }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
    /// The `updatedAt` the server last confirmed. Anything else means unsent.
    var syncedUpdatedAt: Date? { get set }
}

extension Syncable {
    var isDirty: Bool { syncedUpdatedAt != updatedAt }
    /// Distinct from PersistentModel.isDeleted, which means removed from the
    /// context. This one means the row is gone everywhere.
    var isTombstoned: Bool { deletedAt != nil }

    /// Call after changing anything that should reach the other device.
    ///
    /// Stamps are rounded to whole milliseconds because that is all the wire
    /// carries. Keeping the extra nanoseconds locally would make every row
    /// differ from its own round trip and look permanently unsent.
    func touch(_ now: Date = .now) {
        updatedAt = Millis.round(now)
    }

    func tombstone(_ now: Date = .now) {
        let stamp = Millis.round(now)
        if deletedAt == nil { deletedAt = stamp }
        updatedAt = stamp
    }

    func markSynced() {
        syncedUpdatedAt = updatedAt
    }
}
