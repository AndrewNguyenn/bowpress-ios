import Foundation
import Observation

@Observable
final class AppState {
    #if DEBUG
    var isAuthenticated: Bool = true
    var currentUser: User? = User(id: "dev", email: "dev@bowpress.app", name: "Dev Archer", createdAt: Date())
    #else
    var isAuthenticated: Bool = false
    var currentUser: User?
    #endif
    var pendingVerificationEmail: String? = nil
    #if DEBUG
    var bows: [Bow] = DevMockData.bows
    var arrowConfigs: [ArrowConfiguration] = DevMockData.arrowConfigs
    var unreadSuggestionCount: Int = DevMockData.suggestions().filter { !$0.wasRead }.count
    #else
    var bows: [Bow] = []
    var arrowConfigs: [ArrowConfiguration] = []
    var unreadSuggestionCount: Int = 0
    #endif

    /// Single source of truth for each bow's current configuration — read/written
    /// by both the session tab and equipment tab, keyed by bowId.
    var bowConfigs: [String: BowConfiguration] = [:]

    /// Completed sessions available for analytics history, newest first.
    var completedSessions: [ShootingSession] = []

    var entitlement: Entitlement?

    // TODO: real implementation lands in follow-up
    var analyticsRefreshNonce: Int = 0
    /// Bumped after a write that changes a bow's config list (e.g. apply a
    /// suggestion). Equipment-side surfaces (`BowDetailView`,
    /// `ConfigurationView`) `.onChange` of this nonce to refetch.
    var bowConfigsRefreshNonce: Int = 0
    var pendingAnalyticsNavigation: SuggestionNavigationIntent?
    var selectedTab: Int = 0
    var deviceToken: String?

    /// True while `LocalHydration` is seeding the store on launch. Drives the
    /// animated splash overlay in ContentView so we don't flash an empty app.
    var isHydrating: Bool = true

    /// Whether the user has access to paid features.
    ///
    /// In DEBUG this is always `true` so the auto-signed-in dev user can exercise gated
    /// flows without hitting StoreKit. Production gates on the server-issued entitlement.
    /// Pass the `-RealEntitlement` launch arg (Maestro paywall flows do this) to force
    /// the DEBUG build to honor the backend's real entitlement value.
    var isSubscribed: Bool {
        #if DEBUG
        // Honor backend entitlement when REAL_ENTITLEMENT=1 is in the env.
        // Paywall E2E flows set this via SIMCTL_CHILD_REAL_ENTITLEMENT=1 before
        // launching the app. Normal dev runs still get the "always subscribed"
        // shortcut so manual testing isn't gated on StoreKit.
        if ProcessInfo.processInfo.environment["REAL_ENTITLEMENT"] == "1" {
            return entitlement?.isActive == true
        }
        return true
        #else
        return entitlement?.isActive == true
        #endif
    }

    private var lapseObserver: NSObjectProtocol?

    init() {
        lapseObserver = NotificationCenter.default.addObserver(
            forName: .subscriptionLapsed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if var current = self.entitlement {
                current.isActive = false
                self.entitlement = current
            } else {
                self.entitlement = .inactive
            }
        }
    }

    deinit {
        if let lapseObserver {
            NotificationCenter.default.removeObserver(lapseObserver)
        }
    }
}
