import GoogleSignIn
import SwiftUI

struct GoogleSignInButton: View {
    @Environment(AppState.self) private var appState
    var onError: (Error) -> Void

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 12) {
                // Google "G" logo rendered with brand colors
                GoogleGLogo()
                    .frame(width: 20, height: 20)

                Text("Sign in with Google")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color(white: 0.2))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(white: 0.75), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sign in with Google")
    }

    private func handleTap() {
        guard let rootVC = rootViewController() else {
            onError(GoogleSignInError.noRootViewController)
            return
        }

        Task {
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
                guard let idToken = result.user.idToken?.tokenString else {
                    throw GoogleSignInError.missingToken
                }
                let user = try await APIClient.shared.signInWithGoogle(idToken: idToken)
                await MainActor.run {
                    appState.currentUser = user
                    appState.isAuthenticated = true
                }
            } catch {
                // GIDSignInError.canceled — user dismissed the sheet
                if (error as NSError).code == -5 { return }
                await MainActor.run { onError(error) }
            }
        }
    }

    // MARK: - Helpers

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            .flatMap { $0.windows.first { $0.isKeyWindow } }
            .flatMap { findTopViewController($0.rootViewController) }
    }

    private func findTopViewController(_ vc: UIViewController?) -> UIViewController? {
        if let presented = vc?.presentedViewController {
            return findTopViewController(presented)
        }
        if let nav = vc as? UINavigationController {
            return findTopViewController(nav.visibleViewController)
        }
        if let tab = vc as? UITabBarController {
            return findTopViewController(tab.selectedViewController)
        }
        return vc
    }
}

// MARK: - Google "G" Logo

/// Four-color "G" drawn with SwiftUI shapes to avoid asset dependencies.
private struct GoogleGLogo: View {
    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width
            Canvas { ctx, size in
                // Red (top-left arc)
                ctx.fill(gPath(quadrant: 0, size: s), with: .color(googleRed))
                // Blue (top-right arc)
                ctx.fill(gPath(quadrant: 1, size: s), with: .color(googleBlue))
                // Yellow (bottom-right arc)
                ctx.fill(gPath(quadrant: 2, size: s), with: .color(googleYellow))
                // Green (bottom-left arc)
                ctx.fill(gPath(quadrant: 3, size: s), with: .color(googleGreen))
                // White cutout center
                ctx.fill(centerCutout(size: s), with: .color(.white))
                // White right-bar cutout
                ctx.fill(rightBarCutout(size: s), with: .color(.white))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private let googleRed    = Color(red: 0.918, green: 0.263, blue: 0.208)
    private let googleBlue   = Color(red: 0.259, green: 0.522, blue: 0.957)
    private let googleYellow = Color(red: 0.988, green: 0.733, blue: 0.012)
    private let googleGreen  = Color(red: 0.204, green: 0.659, blue: 0.325)

    private func gPath(quadrant: Int, size: CGFloat) -> Path {
        let cx = size / 2, cy = size / 2, r = size / 2
        let startAngle  = Angle.degrees(Double(quadrant) * 90 - 90)
        let endAngle    = Angle.degrees(Double(quadrant) * 90)
        var p = Path()
        p.move(to: CGPoint(x: cx, y: cy))
        p.addArc(center: CGPoint(x: cx, y: cy),
                 radius: r,
                 startAngle: startAngle,
                 endAngle: endAngle,
                 clockwise: false)
        p.closeSubpath()
        return p
    }

    private func centerCutout(size: CGFloat) -> Path {
        Path(ellipseIn: CGRect(
            x: size * 0.25, y: size * 0.25,
            width: size * 0.5, height: size * 0.5
        ))
    }

    private func rightBarCutout(size: CGFloat) -> Path {
        // Horizontal bar on the right side that forms the "G" notch
        Path(CGRect(
            x: size * 0.5, y: size * 0.38,
            width: size * 0.5, height: size * 0.24
        ))
    }
}

// MARK: - Errors

enum GoogleSignInError: LocalizedError {
    case noRootViewController
    case missingToken

    var errorDescription: String? {
        switch self {
        case .noRootViewController: return "Could not find a view controller to present sign-in."
        case .missingToken:         return "Google Sign In did not return a valid ID token."
        }
    }
}

// MARK: - Preview

#Preview {
    let state = AppState()
    GoogleSignInButton(onError: { _ in })
        .environment(state)
        .padding()
        .background(Color(.systemGroupedBackground))
}
