import Foundation
import UIKit

@MainActor
final class NotificationRouter {
    static let shared = NotificationRouter()

    weak var appState: AppState?

    func configure(appState: AppState) {
        self.appState = appState
    }

    /// Foreground arrival — haptic + trigger analytics refresh.
    func handleForegroundArrival(userInfo: [AnyHashable: Any]) async {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        appState?.analyticsRefreshNonce += 1
    }

    /// Notification tap — navigate to Analytics tab and set pending scroll target.
    func handleTap(userInfo: [AnyHashable: Any]) async {
        guard let state = appState else { return }
        if let id = userInfo["suggestionId"] as? String,
           let bowId = userInfo["bowId"] as? String {
            state.pendingAnalyticsNavigation = .suggestion(id: id, bowId: bowId)
        }
        // Analytics tab index in MainTabView — confirmed via Navigation/MainTabView.swift .tag(0)
        state.selectedTab = 0
    }
}
