import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct BowPressApp: App {
    @UIApplicationDelegateAdaptor(BowPressAppDelegate.self) private var appDelegate
    let container: ModelContainer
    let store: LocalStore
    @State private var appState = AppState()

    init() {
        let schema = Schema([
            PersistentBow.self, PersistentBowConfig.self, PersistentArrowConfig.self,
            PersistentSession.self, PersistentArrowPlot.self, PersistentEnd.self, PersistentSuggestion.self,
        ])
        #if DEBUG
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        #else
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        #endif
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
                .onAppear {
                    PushRegistrar.shared.configure(appState: appState)
                    NotificationRouter.shared.configure(appState: appState)
                    SubscriptionManager.shared.configure(appState: appState)
                    Task {
                        await AuthService(appState: appState).restoreIfPossible()
                        if appState.isAuthenticated {
                            await SubscriptionManager.shared.loadProducts()
                            await SubscriptionManager.shared.refreshEntitlement()
                        }
                    }
                }
                .onChange(of: appState.isAuthenticated) { _, authenticated in
                    if authenticated {
                        Task { await PushRegistrar.shared.requestAndRegister() }
                        Task {
                            await SubscriptionManager.shared.loadProducts()
                            await SubscriptionManager.shared.refreshEntitlement()
                        }
                    }
                }
                .onOpenURL { url in
                    // Google Sign-In callbacks get first dibs on any URL.
                    if GIDSignIn.sharedInstance.handle(url) { return }
                    // bowpress://suggestion/{id}?bowId={bowId} — deep-link into Analytics.
                    if url.scheme == "bowpress", url.host == "suggestion" {
                        let id = url.lastPathComponent
                        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
                        let bowId = comps?.queryItems?.first(where: { $0.name == "bowId" })?.value ?? ""
                        if !id.isEmpty {
                            appState.pendingAnalyticsNavigation = .suggestion(id: id, bowId: bowId)
                            appState.selectedTab = 0
                        }
                    }
                }
        }
    }
}
