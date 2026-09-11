import Foundation
import SwiftData

/// One person's portion of one expense. Explicit rather than a split *rule*, so
/// equal, uneven, percentage and "I'll cover Ravi's part" are all the same shape
/// and the balance query stays a single sum.
@Model
final class Share {
    var amountPaise: Int

    /// nil means this is my own portion.
    var person: Person?

    var settledAt: Date?
    var expense: Expense?

    init(amountPaise: Int, person: Person? = nil, settledAt: Date? = nil) {
        self.amountPaise = amountPaise
        self.person = person
        self.settledAt = settledAt
    }

    var isMine: Bool { person == nil }
    var isOutstanding: Bool { settledAt == nil && person != nil }
}
