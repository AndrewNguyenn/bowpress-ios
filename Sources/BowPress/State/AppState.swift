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

    var entitlement: Entitlement?

    /// Whether the user has access to paid features.
    ///
    /// In DEBUG this is always `true` so the auto-signed-in dev user can exercise gated
    /// flows without hitting StoreKit. Production gates on the server-issued entitlement.
    var isSubscribed: Bool {
        #if DEBUG
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
