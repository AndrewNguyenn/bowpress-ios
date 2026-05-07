import SwiftUI
import SwiftData
import GoogleSignIn
#if canImport(UIKit)
import UIKit
#endif

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
            PersistentSightMark.self,
        ])
        #if DEBUG
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        #else
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        #endif
        // The on-disk schema can drift from the in-memory Schema across
        // breaking changes (e.g. renaming a @Model property). When that
        // happens ModelContainer init throws; rather than crash for users
        // updating from an older build we wipe the store and recreate.
        // Server-synced data rehydrates on next launch.
        //
        // Caveat: the wipe drops *every* SwiftData table, not just the one
        // that changed. Any pending offline writes that hadn't drained
        // through BackgroundSyncService are lost. The window is narrow
        // (user has unsynced writes AND launches into a build with a
        // schema change) and we accept it; the alternative is to migrate
        // pending records through the wipe, which doubles the surface area
        // for what should be a once-per-schema-change event.
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            Self.deleteOnDiskStore()
            container = try! ModelContainer(for: schema, configurations: [config])
        }
        self.container = container
        self.store = LocalStore(context: container.mainContext)

        // Belt-and-suspenders for the bowId rename: SwiftData can choose to
        // treat a renamed @Model property as drop-old-add-new rather than
        // throwing, leaving rows with bowId == "". Hydration would re-save
        // those with the server's value, but a row with pendingSync == true
        // would sync upstream as bowId="" first. Sweep them on launch.
        try? Self.purgeOrphanSightMarks(context: container.mainContext)

        // Kenrokuen global chrome — paper tab bar, pondDk selection, ink3 idle.
        #if canImport(UIKit)
        UITabBar.appearance().barTintColor = UIColor(Color.appPaper)
        UITabBar.appearance().backgroundColor = UIColor(Color.appPaper)
        UITabBarItem.appearance().setTitleTextAttributes(
            [
                .foregroundColor: UIColor(Color.appInk3),
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            ],
            for: .normal
        )
        UITabBarItem.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor(Color.appPondDk)],
            for: .selected
        )
        #endif
    }

    private static func deleteOnDiskStore() {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        // SwiftData's default store lives at default.store plus -shm/-wal
        // sidecars. Sweep anything that starts with "default.store".
        if let entries = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
            for url in entries where url.lastPathComponent.hasPrefix("default.store") {
                try? fm.removeItem(at: url)
            }
        }
    }

    private static func purgeOrphanSightMarks(context: ModelContext) throws {
        let descriptor = FetchDescriptor<PersistentSightMark>(
            predicate: #Predicate { $0.bowId.isEmpty }
        )
        for orphan in try context.fetch(descriptor) {
            context.delete(orphan)
        }
        try context.save()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
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
