import XCTest
@testable import BowPress

@MainActor
final class AuthFlowTests: XCTestCase {

    private func makeService() -> (AuthService, AppState, MockAPIClient) {
        let state = AppState()
        state.isAuthenticated = false
        state.currentUser = nil
        state.pendingVerificationEmail = nil
        let mock = MockAPIClient()
        let service = AuthService(appState: state, client: mock)
        return (service, state, mock)
    }

    func test_signUp_doesNotSetAuthenticated_setsPendingEmail() async throws {
        let (service, state, mock) = makeService()
        mock.signUpResult = SignUpResult(email: "new@example.com")

        try await service.signUp(name: "Al", email: "new@example.com", password: "password123")

        XCTAssertFalse(state.isAuthenticated)
        XCTAssertNil(state.currentUser)
        XCTAssertEqual(state.pendingVerificationEmail, "new@example.com")
        XCTAssertEqual(mock.setTokenCalls, [])
        XCTAssertEqual(mock.signUpCallCount, 1)
    }

    func test_verifyEmail_happyPath_setsAuthenticated() async throws {
        let (service, state, mock) = makeService()
        state.pendingVerificationEmail = "new@example.com"
        mock.verifyEmailUser = User(id: "u42", email: "new@example.com", name: "Al", createdAt: Date(timeIntervalSince1970: 1))

        try await service.verifyEmail(email: "new@example.com", code: "482917")

        XCTAssertTrue(state.isAuthenticated)
        XCTAssertEqual(state.currentUser?.id, "u42")
        XCTAssertNil(state.pendingVerificationEmail)
        XCTAssertEqual(mock.verifyEmailCallCount, 1)
        XCTAssertEqual(mock.lastVerifyEmailArgs?.email, "new@example.com")
        XCTAssertEqual(mock.lastVerifyEmailArgs?.code, "482917")
        XCTAssertEqual(mock.setTokenCalls, ["mock-token"])
    }

    func test_verifyEmail_invalidCode_throwsTypedError() async {
        let (service, state, mock) = makeService()
        mock.verifyEmailError = AuthError.invalidCode(attemptsRemaining: 3)

        do {
            try await service.verifyEmail(email: "new@example.com", code: "000000")
            XCTFail("Expected invalidCode error")
        } catch let err as AuthError {
            XCTAssertEqual(err, AuthError.invalidCode(attemptsRemaining: 3))
        } catch {
            XCTFail("Expected AuthError, got \(error)")
        }

        XCTAssertFalse(state.isAuthenticated)
        XCTAssertNil(state.currentUser)
    }

    func test_signIn_unverifiedUser_throwsEmailNotVerifiedWithEmail() async {
        let (service, state, mock) = makeService()
        mock.emailNotVerifiedOnSignIn = true

        do {
            try await service.signIn(email: "pending@example.com", password: "password123")
            XCTFail("Expected emailNotVerified error")
        } catch let err as AuthError {
            XCTAssertEqual(err, AuthError.emailNotVerified(email: "pending@example.com"))
        } catch {
            XCTFail("Expected AuthError, got \(error)")
        }

        XCTAssertFalse(state.isAuthenticated)
        XCTAssertNil(state.currentUser)
    }

    func test_resendVerification_doesNotChangeAuthState() async throws {
        let (service, state, mock) = makeService()
        state.pendingVerificationEmail = "new@example.com"

        try await service.resendVerification(email: "new@example.com")

        XCTAssertFalse(state.isAuthenticated)
        XCTAssertNil(state.currentUser)
        XCTAssertEqual(state.pendingVerificationEmail, "new@example.com")
        XCTAssertEqual(mock.resendVerificationCallCount, 1)
        XCTAssertEqual(mock.lastResendVerificationEmail, "new@example.com")
    }
}
