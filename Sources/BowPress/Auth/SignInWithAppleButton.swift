import AuthenticationServices
import SwiftUI

// MARK: - SwiftUI wrapper

struct SignInWithAppleButton: View {
    @Environment(AppState.self) private var appState
    var onError: (Error) -> Void

    var body: some View {
        AppleSignInButtonRepresentable(appState: appState, onError: onError)
            .frame(height: 50)
            .cornerRadius(8)
            .accessibilityLabel("Sign in with Apple")
    }
}

// MARK: - UIViewRepresentable bridge

private struct AppleSignInButtonRepresentable: UIViewRepresentable {
    let appState: AppState
    let onError: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState, onError: onError)
    }

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handleTap),
            for: .touchUpInside
        )
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
}

// MARK: - Coordinator

final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    private let appState: AppState
    private let onError: (Error) -> Void

    init(appState: AppState, onError: @escaping (Error) -> Void) {
        self.appState = appState
        self.onError = onError
    }

    // Called from the button target
    func startSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Walk the scene hierarchy to find a key window
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
        return scene?.windows.first { $0.isKeyWindow }
            ?? scene?.windows.first
            ?? UIWindow()
    }

    // MARK: ASAuthorizationControllerDelegate

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let identityToken = String(data: tokenData, encoding: .utf8)
        else {
            onError(AppleSignInError.missingToken)
            return
        }

        Task {
            do {
                let user = try await APIClient.shared.signInWithApple(identityToken: identityToken)
                await MainActor.run {
                    appState.currentUser = user
                    appState.isAuthenticated = true
                }
            } catch {
                await MainActor.run { onError(error) }
            }
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        // ASAuthorizationError.canceled is the user tapping Cancel — treat silently
        if let authError = error as? ASAuthorizationError,
           authError.code == .canceled {
            return
        }
        onError(error)
    }
}

// Keep coordinator alive inside the UIViewRepresentable
extension AppleSignInButtonRepresentable {
    final class Coordinator: NSObject {
        let inner: AppleSignInCoordinator

        init(appState: AppState, onError: @escaping (Error) -> Void) {
            self.inner = AppleSignInCoordinator(appState: appState, onError: onError)
        }

        @objc func handleTap() {
            inner.startSignIn()
        }
    }
}

// MARK: - Errors

enum AppleSignInError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Apple Sign In did not return a valid identity token."
        }
    }
}

// MARK: - Preview

#Preview {
    let state = AppState()
    SignInWithAppleButton(onError: { _ in })
        .environment(state)
        .padding()
}
