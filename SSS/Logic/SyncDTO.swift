import Foundation

/// Milliseconds since epoch, which is what the wire and D1 both speak.
///
/// Everything local is rounded to the same resolution the moment it is stamped,
/// so a value that goes to the server and comes back compares equal to itself.
/// Without that, `updatedAt` would differ in the nanoseconds after every round
/// trip and every row would look permanently unsent.
enum Millis {
    static func of(_ date: Date) -> Int {
        Int((date.timeIntervalSince1970 * 1000).rounded())
    }

    static func date(_ value: Int) -> Date {
        Date(timeIntervalSince1970: Double(value) / 1000)
    }

    static func round(_ value: Date) -> Date {
        date(of(value))
    }

    static var now: Date { round(.now) }
}

// MARK: - Wire shapes

struct PersonDTO: Codable {
    var id: UUID
    var name: String
    var upiID: String?
    var createdAt: Int
    var removedAt: Int?
    var updatedAt: Int
    var deletedAt: Int?
}

struct GroupDTO: Codable {
    var id: UUID
    var name: String
    var createdAt: Int
    var closedAt: Int?
    var memberIDs: [UUID]
    var updatedAt: Int
    var deletedAt: Int?
}

struct ExpenseDTO: Codable {
    var id: UUID
    var amountPaise: Int
    var note: String
    var spentAt: Int
    var isEssential: Bool
    var payerID: UUID?
    var groupID: UUID?
    var updatedAt: Int
    var deletedAt: Int?
}

struct ShareDTO: Codable {
    var id: UUID
    var expenseID: UUID
    var personID: UUID?
    var amountPaise: Int
    var settledAt: Int?
    var updatedAt: Int
    var deletedAt: Int?
}

struct SyncPayload: Codable {
    var people: [PersonDTO] = []
    var groups: [GroupDTO] = []
    var expenses: [ExpenseDTO] = []
    var shares: [ShareDTO] = []

    var isEmpty: Bool {
        people.isEmpty && groups.isEmpty && expenses.isEmpty && shares.isEmpty
    }

    var count: Int {
        people.count + groups.count + expenses.count + shares.count
    }
}

struct SyncRequest: Encodable {
    var since: Int
    var people: [PersonDTO]
    var groups: [GroupDTO]
    var expenses: [ExpenseDTO]
    var shares: [ShareDTO]

    init(since: Int, push: SyncPayload) {
        self.since = since
        self.people = push.people
        self.groups = push.groups
        self.expenses = push.expenses
        self.shares = push.shares
    }
}

struct SyncResponse: Decodable {
    var until: Int
    var hasMore: Bool
    var people: [PersonDTO]
    var groups: [GroupDTO]
    var expenses: [ExpenseDTO]
    var shares: [ShareDTO]

    var payload: SyncPayload {
        SyncPayload(people: people, groups: groups, expenses: expenses, shares: shares)
    }
}
