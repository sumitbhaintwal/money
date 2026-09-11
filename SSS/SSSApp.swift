import SwiftUI
import SwiftData

@main
struct SSSApp: App {
    private let container: ModelContainer
    @State private var session = SessionStore()

    init() {
        do {
            container = try ModelContainer(for: Expense.self, Person.self, Share.self)
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
                .tint(Theme.lit)
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}
