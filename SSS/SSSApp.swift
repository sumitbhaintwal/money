import SwiftUI
import SwiftData

@main
struct SSSApp: App {
    @Environment(\.scenePhase) private var phase

    private let container: ModelContainer
    @State private var session: SessionStore
    @State private var sync: SyncEngine

    init() {
        let container = Self.openStore()
        let session = SessionStore()
        self.container = container
        _session = State(initialValue: session)
        _sync = State(initialValue: SyncEngine(container: container, session: session))

        #if DEBUG
        // Sample data would otherwise be uploaded to a real account on the next
        // sync. Only ever seed a phone that nobody has signed into.
        if !session.isSignedIn {
            SampleData.seedIfEmpty(container.mainContext)
        }
        #endif
    }

    /// The store is a cache of the account's ledger, not the only copy, so a
    /// schema it cannot open is worth discarding rather than crashing on. What
    /// was in it comes back down on the next sync.
    private static func openStore() -> ModelContainer {
        let models: [any PersistentModel.Type] = [Expense.self, Person.self, Share.self, ExpenseGroup.self]
        let schema = Schema(models)
        do {
            return try ModelContainer(for: schema)
        } catch {
            let store = URL.applicationSupportDirectory.appending(path: "default.store")
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: store.path() + suffix))
            }
            do {
                return try ModelContainer(for: schema)
            } catch {
                fatalError("Could not open the local store: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(sync)
                // A token revoked elsewhere would otherwise leave the app
                // looking signed in until something happened to fail.
                .task {
                    await session.refresh()
                    await sync.syncNow()
                }
                // One hook rather than a call after every save: a sync that is
                // remembered at twelve call sites is a sync that gets forgotten
                // at the thirteenth.
                .task {
                    for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave) {
                        sync.schedule()
                    }
                }
                .tint(Theme.lit)
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
        .onChange(of: phase) { _, new in
            if new == .active { Task { await sync.syncNow() } }
        }
    }
}
