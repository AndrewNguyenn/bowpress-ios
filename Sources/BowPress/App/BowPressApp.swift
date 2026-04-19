import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct BowPressApp: App {
    let container: ModelContainer
    let store: LocalStore
    @State private var appState = AppState()

    init() {
        let schema = Schema([
            PersistentBow.self, PersistentBowConfig.self, PersistentArrowConfig.self,
            PersistentSession.self, PersistentArrowPlot.self, PersistentEnd.self, PersistentSuggestion.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try! ModelContainer(for: schema, configurations: [config])
        self.container = container
        self.store = LocalStore(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(store)
                .modelContainer(container)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
