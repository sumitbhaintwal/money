import SwiftUI
import SwiftData

@main
struct SSSApp: App {
    private let container: ModelContainer

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
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}
