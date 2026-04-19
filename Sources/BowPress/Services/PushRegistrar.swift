import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushRegistrar {
    static let shared = PushRegistrar()

    weak var appState: AppState?

    func configure(appState: AppState) {
        self.appState = appState
    }

    /// Request notification authorization and trigger APNs registration.
    /// Call this after the user has signed in.
    func requestAndRegister() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        guard granted else {
            print("[Push] authorization denied")
            return
        }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func onTokenReceived(hex: String) {
        appState?.deviceToken = hex
        let environment: String
        #if DEBUG
        environment = "development"
        #else
        environment = "production"
        #endif
        Task {
            do {
                try await APIClient.shared.registerDeviceToken(hex, environment: environment)
                print("[Push] token registered with backend")
            } catch {
                print("[Push] failed to register token: \(error)")
            }
        }
    }
}
