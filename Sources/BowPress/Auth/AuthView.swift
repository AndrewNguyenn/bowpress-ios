import SwiftUI

struct AuthView: View {
    @Environment(AppState.self) private var appState

    // AuthService is lazily created on first appear so it always holds the correct AppState.
    @State private var authService: AuthService? = nil
    @State private var showEmailAuth: Bool = false
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
            VStack(spacing: 14) {
                // 1. Sign in with Apple
                SignInWithAppleButton(onError: present(error:))
                    .frame(height: 50)

                // 2. Sign in with Google
                GoogleSignInButton(onError: present(error:))
                    .frame(height: 50)

                // 3. Continue with Email
                Button(action: { showEmailAuth = true }) {
                    Text("Continue with Email")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.appBorder, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Continue with Email")
            }
            .padding(.horizontal, 32)

            Spacer()

            // MARK: Footer
            Text("By continuing you agree to our Terms of Service and Privacy Policy.")
                .font(.caption)
                .foregroundStyle(.tertiary)
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
        .sheet(isPresented: $showEmailAuth) {
            // Capture service at sheet-presentation time (authService is set by onAppear)
            if let svc = authService {
                EmailAuthView(authService: svc)
                    .environment(appState)
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
