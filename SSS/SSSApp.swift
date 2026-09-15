import SwiftUI
import SwiftData

@main
struct SSSApp: App {
    private let container: ModelContainer
    @State private var session = SessionStore()

    init() {
        do {
            container = try ModelContainer(for: Expense.self, Person.self, Share.self, ExpenseGroup.self)
        } catch {
            fatalError("Could not open the local store: \(error)")
        }
        #if DEBUG
        SampleData.seedIfEmpty(container.mainContext)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                // A token revoked elsewhere would otherwise leave the app
                // looking signed in until something happened to fail.
                .task { await session.refresh() }
                .tint(Theme.lit)
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}
