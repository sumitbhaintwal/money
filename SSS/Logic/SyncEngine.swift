import Foundation
import Observation
import SwiftData

/// Keeps the phone's ledger and the account's ledger the same.
///
/// Offline first, deliberately. The whole claim of this app is that logging an
/// expense takes seconds, and a version that needs a signal to record a chai on
/// the metro is a worse app than the one it replaced. Everything is written to
/// SwiftData immediately; this pushes it up afterwards and pulls down whatever
/// the other device did.
///
/// Conflicts are last-write-wins on `updatedAt`. That is the right call here and
/// not a shortcut: the only way two rows can disagree is one person editing the
/// same expense on their phone and their iPad, and the later edit is the one
/// they meant.
@MainActor
@Observable
final class SyncEngine {

    enum Status: Equatable {
        case idle
        case syncing
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var lastSyncedAt: Date?

    private let container: ModelContainer
    private let session: SessionStore
    private let service: SyncService

    private var pending: Task<Void, Never>?
    private var isRunning = false

    private let cursorKey = "sss.sync.cursor"
    private let accountKey = "sss.sync.account"

    init(container: ModelContainer, session: SessionStore, service: SyncService = HTTPSyncService()) {
        self.container = container
        self.session = session
        self.service = service
        self.lastSyncedAt = UserDefaults.standard.object(forKey: "sss.sync.at") as? Date
    }

    private var context: ModelContext { container.mainContext }

    // MARK: - Triggers

    /// Coalesces the burst of saves a single edit produces into one round trip.
    func schedule(after seconds: Double = 2) {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    func syncNow() async {
        guard let token = session.bearerToken, let accountID = session.account?.id else { return }
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        // Signing in as somebody else must not hand them the previous account's
        // ledger. The local store belongs to exactly one account at a time.
        if storedAccount != accountID {
            wipeLocalLedger()
            cursor = 0
            storedAccount = accountID
        }

        status = .syncing

        // `hasMore` means the pull was cut at a page boundary, not that anything
        // went wrong — a restored phone's first sync is many pages.
        for _ in 0..<50 {
            do {
                let outgoing = gatherDirty()
                let response = try await service.sync(
                    SyncRequest(since: cursor, push: outgoing),
                    token: token
                )

                apply(response.payload)
                confirm(outgoing)
                purgeConfirmedTombstones()
                try? context.save()

                cursor = response.until
                lastSyncedAt = .now
                UserDefaults.standard.set(lastSyncedAt, forKey: "sss.sync.at")
                status = .idle

                if !response.hasMore { return }
            } catch let error as AuthError where error.code == "unauthorized" {
                status = .failed("Signed out. Sign in again to keep syncing.")
                return
            } catch let error as AuthError {
                status = .failed(error.message)
                return
            } catch {
                status = .failed(AuthError.offline.message)
                return
            }
        }
    }

    /// Pushes whatever is unsent, then leaves nothing behind on the device.
    func signOutAndWipe() async {
        await syncNow()
        await session.signOut()
        wipeLocalLedger()
        try? context.save()
        cursor = 0
        storedAccount = nil
        status = .idle
    }

    // MARK: - Cursor

    private var cursor: Int {
        get { UserDefaults.standard.integer(forKey: cursorKey) }
        set { UserDefaults.standard.set(newValue, forKey: cursorKey) }
    }

    private var storedAccount: String? {
        get { UserDefaults.standard.string(forKey: accountKey) }
        set { UserDefaults.standard.set(newValue, forKey: accountKey) }
    }

    // MARK: - Push

    private func gatherDirty() -> SyncPayload {
        var payload = SyncPayload()

        for person in fetch(Person.self) where person.isDirty {
            payload.people.append(PersonDTO(
                id: person.id,
                name: person.name,
                upiID: person.upiID,
                createdAt: Millis.of(person.createdAt),
                removedAt: person.removedAt.map(Millis.of),
                updatedAt: Millis.of(person.updatedAt),
                deletedAt: person.deletedAt.map(Millis.of)
            ))
        }

        for group in fetch(ExpenseGroup.self) where group.isDirty {
            payload.groups.append(GroupDTO(
                id: group.id,
                name: group.name,
                createdAt: Millis.of(group.createdAt),
                closedAt: group.closedAt.map(Millis.of),
                memberIDs: group.storedMembers.map(\.id),
                updatedAt: Millis.of(group.updatedAt),
                deletedAt: group.deletedAt.map(Millis.of)
            ))
        }

        for expense in fetch(Expense.self) where expense.isDirty {
            payload.expenses.append(ExpenseDTO(
                id: expense.id,
                amountPaise: expense.amountPaise,
                note: expense.note,
                spentAt: Millis.of(expense.spentAt),
                isEssential: expense.isEssential,
                payerID: expense.payer?.id,
                groupID: expense.group?.id,
                updatedAt: Millis.of(expense.updatedAt),
                deletedAt: expense.deletedAt.map(Millis.of)
            ))
        }

        for share in fetch(Share.self) where share.isDirty {
            // A share with no expense cannot be addressed on the server and
            // means nothing on its own, so it is dropped rather than sent.
            guard let expenseID = share.expense?.id else { continue }
            payload.shares.append(ShareDTO(
                id: share.id,
                expenseID: expenseID,
                personID: share.person?.id,
                amountPaise: share.amountPaise,
                settledAt: share.settledAt.map(Millis.of),
                updatedAt: Millis.of(share.updatedAt),
                deletedAt: share.deletedAt.map(Millis.of)
            ))
        }

        return payload
    }

    /// Marks what was sent as sent — but only where it has not been edited again
    /// while the request was in flight, or that edit would never be pushed.
    private func confirm(_ pushed: SyncPayload) {
        let people = Dictionary(uniqueKeysWithValues: pushed.people.map { ($0.id, $0.updatedAt) })
        let groups = Dictionary(uniqueKeysWithValues: pushed.groups.map { ($0.id, $0.updatedAt) })
        let expenses = Dictionary(uniqueKeysWithValues: pushed.expenses.map { ($0.id, $0.updatedAt) })
        let shares = Dictionary(uniqueKeysWithValues: pushed.shares.map { ($0.id, $0.updatedAt) })

        func settle<T: Syncable>(_ rows: [T], _ sent: [UUID: Int]) {
            for row in rows {
                guard let stamp = sent[row.id], stamp == Millis.of(row.updatedAt) else { continue }
                row.markSynced()
            }
        }

        settle(fetch(Person.self), people)
        settle(fetch(ExpenseGroup.self), groups)
        settle(fetch(Expense.self), expenses)
        settle(fetch(Share.self), shares)
    }

    /// Once the server has the tombstone, the local row has nothing left to say.
    private func purgeConfirmedTombstones() {
        for share in fetch(Share.self) where share.isTombstoned && !share.isDirty {
            context.delete(share)
        }
        for expense in fetch(Expense.self) where expense.isTombstoned && !expense.isDirty {
            context.delete(expense)
        }
        for group in fetch(ExpenseGroup.self) where group.isTombstoned && !group.isDirty {
            context.delete(group)
        }
        for person in fetch(Person.self) where person.isTombstoned && !person.isDirty {
            context.delete(person)
        }
    }

    // MARK: - Pull

    private func apply(_ remote: SyncPayload) {
        var peopleByID = index(fetch(Person.self))
        var groupsByID = index(fetch(ExpenseGroup.self))
        var expensesByID = index(fetch(Expense.self))
        var sharesByID = index(fetch(Share.self))

        for dto in remote.people {
            let stamp = Millis.date(dto.updatedAt)
            guard let person = resolve(dto.id, in: &peopleByID, stamp: stamp, deleted: dto.deletedAt != nil, make: {
                let fresh = Person(name: dto.name, createdAt: Millis.date(dto.createdAt), id: dto.id)
                context.insert(fresh)
                return fresh
            }) else { continue }

            person.name = dto.name
            person.upiID = dto.upiID
            person.createdAt = Millis.date(dto.createdAt)
            person.removedAt = dto.removedAt.map(Millis.date)
            accept(person, dto.updatedAt, dto.deletedAt)
        }

        for dto in remote.groups {
            let stamp = Millis.date(dto.updatedAt)
            guard let group = resolve(dto.id, in: &groupsByID, stamp: stamp, deleted: dto.deletedAt != nil, make: {
                let fresh = ExpenseGroup(name: dto.name, createdAt: Millis.date(dto.createdAt), id: dto.id)
                context.insert(fresh)
                return fresh
            }) else { continue }

            group.name = dto.name
            group.createdAt = Millis.date(dto.createdAt)
            group.closedAt = dto.closedAt.map(Millis.date)
            group.storedMembers = dto.memberIDs.compactMap { peopleByID[$0] }
            accept(group, dto.updatedAt, dto.deletedAt)
        }

        for dto in remote.expenses {
            let stamp = Millis.date(dto.updatedAt)
            guard let expense = resolve(dto.id, in: &expensesByID, stamp: stamp, deleted: dto.deletedAt != nil, make: {
                let fresh = Expense(
                    amountPaise: dto.amountPaise,
                    note: dto.note,
                    spentAt: Millis.date(dto.spentAt),
                    id: dto.id
                )
                context.insert(fresh)
                return fresh
            }) else { continue }

            expense.amountPaise = dto.amountPaise
            expense.note = dto.note
            expense.spentAt = Millis.date(dto.spentAt)
            expense.isEssential = dto.isEssential
            expense.payer = dto.payerID.flatMap { peopleByID[$0] }
            expense.group = dto.groupID.flatMap { groupsByID[$0] }
            accept(expense, dto.updatedAt, dto.deletedAt)
        }

        for dto in remote.shares {
            // Without its expense a share has no home and no meaning. This only
            // happens if the expense was dropped as malformed, so skipping is
            // better than attaching it to nothing.
            guard let expense = expensesByID[dto.expenseID] else { continue }
            let stamp = Millis.date(dto.updatedAt)
            guard let share = resolve(dto.id, in: &sharesByID, stamp: stamp, deleted: dto.deletedAt != nil, make: {
                let fresh = Share(amountPaise: dto.amountPaise, id: dto.id, updatedAt: stamp)
                context.insert(fresh)
                fresh.expense = expense
                return fresh
            }) else { continue }

            share.expense = expense
            share.person = dto.personID.flatMap { peopleByID[$0] }
            share.amountPaise = dto.amountPaise
            share.settledAt = dto.settledAt.map(Millis.date)
            accept(share, dto.updatedAt, dto.deletedAt)
        }
    }

    /// Finds the local row, creates it, or declines — whichever is right.
    ///
    /// Declining covers two cases. A tombstone for a row this device never had
    /// is nothing to do: creating it just to mark it deleted would resurrect
    /// rows that were already purged. And a local row with a newer stamp wins,
    /// because it is the edit that happened later.
    private func resolve<T: Syncable>(
        _ id: UUID,
        in known: inout [UUID: T],
        stamp: Date,
        deleted: Bool,
        make: () -> T
    ) -> T? {
        if let existing = known[id] {
            guard stamp > existing.updatedAt else { return nil }
            return existing
        }
        guard !deleted else { return nil }
        let fresh = make()
        known[id] = fresh
        return fresh
    }

    private func accept(_ row: some Syncable, _ updatedAt: Int, _ deletedAt: Int?) {
        row.deletedAt = deletedAt.map(Millis.date)
        row.updatedAt = Millis.date(updatedAt)
        row.markSynced()
    }

    // MARK: - Store

    private func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    private func index<T: Syncable & PersistentModel>(_ rows: [T]) -> [UUID: T] {
        Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func wipeLocalLedger() {
        try? context.delete(model: Share.self)
        try? context.delete(model: Expense.self)
        try? context.delete(model: ExpenseGroup.self)
        try? context.delete(model: Person.self)
        try? context.save()
    }
}

// MARK: - Transport

protocol SyncService: Sendable {
    func sync(_ request: SyncRequest, token: String) async throws -> SyncResponse
}

struct HTTPSyncService: SyncService {
    var baseURL: URL = AppConfig.apiBaseURL

    func sync(_ payload: SyncRequest, token: String) async throws -> SyncResponse {
        var request = URLRequest(url: baseURL.appending(path: "/v1/me/sync"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)
        // A first sync on a restored phone is a big upload on a slow connection.
        request.timeoutInterval = 60

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.offline
        }

        guard let http = response as? HTTPURLResponse else { throw AuthError.unexpected }

        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw AuthError(code: "unauthorized", message: "Signed out.")
            }
            if let failure = try? JSONDecoder().decode(SyncFailure.self, from: data) {
                throw AuthError(code: failure.error, message: failure.message ?? AuthError.unexpected.message)
            }
            throw AuthError.unexpected
        }

        do {
            return try JSONDecoder().decode(SyncResponse.self, from: data)
        } catch {
            throw AuthError.unexpected
        }
    }
}

private struct SyncFailure: Decodable {
    let error: String
    let message: String?
}
