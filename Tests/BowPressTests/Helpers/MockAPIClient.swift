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

    // Subscription stubs
    var entitlementToReturn: Entitlement = .inactive
    var verifyAppleEntitlementToReturn: Entitlement = .inactive
    var fetchEntitlementError: Error?
    var verifyAppleError: Error?
    private(set) var fetchEntitlementCallCount: Int = 0
    private(set) var verifyAppleCallCount: Int = 0
    private(set) var lastVerifyAppleJws: String?

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

    // MARK: - Persistence-related stubs (unused by auth tests)

    func fetchBows() async throws -> [Bow] { [] }
    func createBow(_ bow: Bow) async throws -> Bow { bow }
    func deleteBow(id: String) async throws {}
    func fetchConfigurations(bowId: String) async throws -> [BowConfiguration] { [] }
    func createConfiguration(_ config: BowConfiguration) async throws -> BowConfiguration { config }
    func fetchArrowConfigs() async throws -> [ArrowConfiguration] { [] }
    func createArrowConfig(_ config: ArrowConfiguration) async throws -> ArrowConfiguration { config }
    func deleteArrowConfig(id: String) async throws {}
    func fetchSessions() async throws -> [ShootingSession] { [] }
    func createSession(_ session: ShootingSession) async throws -> ShootingSession { session }
    func endSession(id: String, notes: String) async throws {}
    func updateSession(id: String, notes: String, feelTags: [String]) async throws {}
    func deleteSession(id: String) async throws {}
    func fetchPlots(sessionId: String) async throws -> [ArrowPlot] { [] }
    func plotArrow(_ plot: ArrowPlot) async throws -> ArrowPlot { plot }
    func deletePlot(sessionId: String, id: String) async throws {}
    func completeEnd(_ end: SessionEnd) async throws -> SessionEnd { end }

    // MARK: - Subscription

    func fetchEntitlement() async throws -> Entitlement {
        fetchEntitlementCallCount += 1
        if let err = fetchEntitlementError { throw err }
        return entitlementToReturn
    }

    func verifyAppleTransaction(jws: String) async throws -> Entitlement {
        verifyAppleCallCount += 1
        lastVerifyAppleJws = jws
        if let err = verifyAppleError { throw err }
        return verifyAppleEntitlementToReturn
    }

    // MARK: - Suggestion stubs (overridable per-test via the closures)

    var fetchSuggestionImpl: ((String, String) async throws -> AnalyticsSuggestion)?
    var applySuggestionImpl: ((String, String) async throws -> ApplyResult)?

    func fetchSuggestion(bowId: String, id: String) async throws -> AnalyticsSuggestion {
        if let impl = fetchSuggestionImpl { return try await impl(bowId, id) }
        throw URLError(.fileDoesNotExist)
    }

    func applySuggestion(bowId: String, id: String) async throws -> ApplyResult {
        if let impl = applySuggestionImpl { return try await impl(bowId, id) }
        throw URLError(.fileDoesNotExist)
    }
}
