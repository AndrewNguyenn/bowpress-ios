import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class BowPressAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            PushRegistrar.shared.onTokenReceived(hex: hex)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[Push] register failed: \(error)")
    }

    // Foreground — show banner + sound, trigger refresh
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        await NotificationRouter.shared.handleForegroundArrival(
            userInfo: notification.request.content.userInfo
        )
        return [.banner, .sound, .badge]
    }

    // Tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await NotificationRouter.shared.handleTap(
            userInfo: response.notification.request.content.userInfo
        )
    }
}
