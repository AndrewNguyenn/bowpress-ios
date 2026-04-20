import Foundation

#if DEBUG
/// Auto sign-in for DEBUG builds so the app always boots with the e2e test
/// user's data from the API. Matches the server-side seed
/// (`bowpress-api/scripts/seed-e2e.ts`).
enum DevAutoSignIn {
    static let defaultEmail = "e2e-test@bowpress.dev"
    static let defaultPassword = "bowpress-e2e-pw-1234"

    static var email: String { launchArgValue(for: "-AutoSignInEmail") ?? defaultEmail }
    static var password: String { launchArgValue(for: "-AutoSignInPassword") ?? defaultPassword }

    private static var hasExplicitLaunchArg: Bool { launchArgValue(for: "-AutoSignInEmail") != nil }

    static func ensureSignedIn() async {
        let api = APIClient.shared
        // If the launch arg explicitly picks a user, always (re-)sign in so a
        // keychain-persisted token from a previous role can't leak across
        // Maestro flows. Otherwise honor any existing token.
        if api.hasToken && !hasExplicitLaunchArg { return }
        if hasExplicitLaunchArg { api.clearToken() }
        do {
            _ = try await api.signIn(email: email, password: password)
        } catch {
            print("[DevAutoSignIn] sign-in failed: \(error.localizedDescription)")
        }
    }

    private static func launchArgValue(for flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: flag), idx + 1 < args.count else { return nil }
        let value = args[idx + 1]
        return value.isEmpty ? nil : value
    }
}
#endif
