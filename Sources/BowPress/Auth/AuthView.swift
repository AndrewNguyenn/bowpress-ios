import SwiftUI

struct AuthView: View {
    @Environment(AppState.self) private var appState

    // AuthService is lazily created on first appear so it always holds the correct AppState.
    @State private var authService: AuthService? = nil
    @State private var errorMessage: String? = nil
    @State private var showError: Bool = false

    /// Non-optional accessor — falls back to a temporary instance before onAppear fires
    /// (e.g. in Xcode Previews). Once onAppear runs the @State is stable.
    private var service: AuthService {
        authService ?? AuthService(appState: appState)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // MARK: Logo + headline
            VStack(spacing: 16) {
                #if canImport(UIKit)
                LottieView(name: "archery_hero", loopMode: .loop)
                    .frame(width: 160, height: 160)
                #else
                Image(systemName: "scope")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundStyle(Color.appAccent)
                    .symbolEffect(.pulse, options: .repeating)
                #endif

                Text("BowPress")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)

                Text("Tune smarter. Shoot better.")
                    .font(.title3)
                    .foregroundStyle(Color.appText)
            }
            .padding(.bottom, 56)

            // MARK: Sign-in buttons
            // Email/password sign-in was removed because BowPress doesn't
            // own a verified sending domain (verification + reset emails
            // can't be delivered reliably from Resend's onboarding domain).
            // Existing email-auth accounts still resolve through Apple/Google
            // by email-fallback in /auth/signin-{apple,google}.
            VStack(spacing: 14) {
                SignInWithAppleButton(onError: present(error:))
                    .frame(height: 50)

                GoogleSignInButton(onError: present(error:))
                    .frame(height: 50)
            }
            .padding(.horizontal, 32)

            Spacer()

            // MARK: Footer
            VStack(spacing: 6) {
                Text("By continuing you agree to our")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                HStack(spacing: 16) {
                    Link("Terms of Service",
                         destination: URL(string: "https://andrewnguyenn.github.io/bowpress-web/terms.html")!)
                    Link("Privacy Policy",
                         destination: URL(string: "https://andrewnguyenn.github.io/bowpress-web/privacy.html")!)
                }
                .font(.caption.weight(.medium))
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .onAppear {
            // Initialise once so the object keeps the correct appState reference
            if authService == nil {
                authService = AuthService(appState: appState)
            }
        }
        .alert("Sign In Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
        // Expose AuthService to child views that want it via @Environment
        .environment(service)
    }

    private func present(error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}

// MARK: - Preview

#Preview("Unauthenticated") {
    let state = AppState()
    AuthView()
        .environment(state)
}

#Preview("Dark Mode") {
    let state = AppState()
    AuthView()
        .environment(state)
        .preferredColorScheme(.dark)
}
