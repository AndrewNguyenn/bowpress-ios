import Foundation
import AuthenticationServices
import GoogleSignIn
#if canImport(UIKit)
import UIKit
#endif

@Observable
final class AuthService: NSObject {
    var appState: AppState
    private let client: BowPressAPIClient

    init(appState: AppState, client: BowPressAPIClient = APIClient.shared) {
        self.appState = appState
        self.client = client
    }

    func signInWithApple() async throws {
        // Feature agent will implement
    }

    #if canImport(UIKit)
    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        // Feature agent will implement
    }
    #endif

    func signIn(email: String, password: String) async throws {
        let user = try await client.signIn(email: email, password: password)
        appState.currentUser = user
        appState.isAuthenticated = true
        appState.pendingVerificationEmail = nil
    }

    func signUp(name: String, email: String, password: String) async throws {
        let result = try await client.signUp(name: name, email: email, password: password)
        appState.pendingVerificationEmail = result.email
    }

    func verifyEmail(email: String, code: String) async throws {
        let user = try await client.verifyEmail(email: email, code: code)
        appState.currentUser = user
        appState.isAuthenticated = true
        appState.pendingVerificationEmail = nil
    }

    func resendVerification(email: String) async throws {
        try await client.resendVerification(email: email)
    }

    func signOut() {
        appState.currentUser = nil
        appState.isAuthenticated = false
        appState.pendingVerificationEmail = nil
        GIDSignIn.sharedInstance.signOut()
        if let apiClient = client as? APIClient {
            apiClient.clearToken()
        }
    }

    /// Restore auth state from a persisted Keychain token on launch.
    /// Optimistically flips `isAuthenticated` so the UI doesn't flash the
    /// sign-in screen, then validates with the server. Only clears the
    /// token on an explicit auth failure (401/403) — transient network
    /// errors leave the cached session intact so offline launches still
    /// land on MainTabView.
    func restoreIfPossible() async {
        guard let apiClient = client as? APIClient, apiClient.hasToken else { return }
        appState.isAuthenticated = true
        do {
            let user = try await apiClient.fetchProfile()
            appState.currentUser = user
        } catch let error as NSError {
            if error.domain == "APIClient" && (error.code == 401 || error.code == 403) {
                apiClient.clearToken()
                appState.currentUser = nil
                appState.isAuthenticated = false
            }
            // Other errors (offline, 5xx): keep the cached session.
        }
    }
}
