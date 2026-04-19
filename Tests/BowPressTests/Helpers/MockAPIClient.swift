import Foundation
@testable import BowPress

final class MockAPIClient: BowPressAPIClient {
    // MARK: - Spies

    private(set) var setTokenCalls: [String] = []
    private(set) var signInCallCount: Int = 0
    private(set) var signUpCallCount: Int = 0
    private(set) var verifyEmailCallCount: Int = 0
    private(set) var resendVerificationCallCount: Int = 0

    private(set) var lastSignUpArgs: (name: String, email: String, password: String)?
    private(set) var lastSignInArgs: (email: String, password: String)?
    private(set) var lastVerifyEmailArgs: (email: String, code: String)?
    private(set) var lastResendVerificationEmail: String?

    // MARK: - Stubs

    var emailNotVerifiedOnSignIn: Bool = false
    var signInUser: User = User(id: "u1", email: "test@example.com", name: "Test", createdAt: Date(timeIntervalSince1970: 0))
    var signUpResult: SignUpResult = SignUpResult(email: "test@example.com")
    var verifyEmailUser: User = User(id: "u1", email: "test@example.com", name: "Test", createdAt: Date(timeIntervalSince1970: 0))
    var verifyEmailError: AuthError?
    var resendError: Error?

    // MARK: - Protocol

    func setToken(_ token: String) {
        setTokenCalls.append(token)
    }

    func signInWithApple(identityToken: String) async throws -> User { signInUser }
    func signInWithGoogle(idToken: String) async throws -> User { signInUser }

    func signUp(name: String, email: String, password: String) async throws -> SignUpResult {
        signUpCallCount += 1
        lastSignUpArgs = (name, email, password)
        return signUpResult
    }

    func signIn(email: String, password: String) async throws -> User {
        signInCallCount += 1
        lastSignInArgs = (email, password)
        if emailNotVerifiedOnSignIn {
            throw AuthError.emailNotVerified(email: email)
        }
        setToken("mock-token")
        return signInUser
    }

    func verifyEmail(email: String, code: String) async throws -> User {
        verifyEmailCallCount += 1
        lastVerifyEmailArgs = (email, code)
        if let err = verifyEmailError { throw err }
        setToken("mock-token")
        return verifyEmailUser
    }

    func resendVerification(email: String) async throws {
        resendVerificationCallCount += 1
        lastResendVerificationEmail = email
        if let err = resendError { throw err }
    }
}
