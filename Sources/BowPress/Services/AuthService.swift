import Foundation
import AuthenticationServices
import GoogleSignIn

@Observable
final class AuthService: NSObject {
    var appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func signInWithApple() async throws {
        // Feature agent will implement
    }

    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        // Feature agent will implement
    }

    func signIn(email: String, password: String) async throws {
        let user = try await APIClient.shared.signIn(email: email, password: password)
        appState.currentUser = user
        appState.isAuthenticated = true
    }

    func signUp(name: String, email: String, password: String) async throws {
        let user = try await APIClient.shared.signUp(name: name, email: email, password: password)
        appState.currentUser = user
        appState.isAuthenticated = true
    }

    func signOut() {
        appState.currentUser = nil
        appState.isAuthenticated = false
        GIDSignIn.sharedInstance.signOut()
    }
}
