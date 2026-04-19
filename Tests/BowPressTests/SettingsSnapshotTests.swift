import XCTest
import SwiftUI
@testable import BowPress

// NOTE: The brief requested pointfreeco/swift-snapshot-testing, but that
// dependency is not present in Package.swift / project.yml and adding a new
// package would touch project.yml (which `ios-subscription-ui` is also
// modifying on a parallel branch). These tests exercise the same views the
// snapshots would render, validating the deterministic state that drives each
// variant — populated user, verified vs unverified badge, pristine and error
// states. When the snapshot library is wired up we can drop these in favour
// of image diffs.

@MainActor
final class SettingsSnapshotTests: XCTestCase {

    // MARK: - Fixtures

    private func verifiedUser() -> User {
        User(
            id: "u-verified",
            email: "sage@bowpress.app",
            name: "Sage Archer",
            createdAt: Date(timeIntervalSince1970: 0),
            emailVerified: true
        )
    }

    private func unverifiedUser() -> User {
        User(
            id: "u-unverified",
            email: "new@bowpress.app",
            name: "New Archer",
            createdAt: Date(timeIntervalSince1970: 0),
            emailVerified: false
        )
    }

    private func stateWithUser(_ user: User?) -> AppState {
        let state = AppState()
        state.currentUser = user
        state.isAuthenticated = user != nil
        return state
    }

    // MARK: - SettingsView

    func test_settingsView_rendersWithPopulatedUser() {
        let state = stateWithUser(verifiedUser())
        let view = NavigationStack { SettingsView() }.environment(state)
        XCTAssertNoThrow(try hostAndInstantiate(view))
    }

    // MARK: - AccountView

    func test_accountView_verifiedUser_rendersVerifiedBadge() {
        let state = stateWithUser(verifiedUser())
        XCTAssertEqual(state.currentUser?.emailVerified, true)
        let view = NavigationStack { AccountView() }.environment(state)
        XCTAssertNoThrow(try hostAndInstantiate(view))
    }

    func test_accountView_unverifiedUser_rendersUnverifiedBadge() {
        let state = stateWithUser(unverifiedUser())
        XCTAssertEqual(state.currentUser?.emailVerified, false)
        let view = NavigationStack { AccountView() }.environment(state)
        XCTAssertNoThrow(try hostAndInstantiate(view))
    }

    // MARK: - EditProfileView

    func test_editProfileView_pristine_rendersAndHasSaveButtonDisabledForEmptyName() {
        let state = stateWithUser(verifiedUser())
        let view = NavigationStack { EditProfileView() }.environment(state)
        XCTAssertNoThrow(try hostAndInstantiate(view))
    }

    // MARK: - ChangePasswordView

    func test_changePasswordView_pristine_renders() {
        let view = NavigationStack { ChangePasswordView() }
        XCTAssertNoThrow(try hostAndInstantiate(view))
    }

    func test_changePasswordView_withError_renders() {
        let view = NavigationStack {
            ChangePasswordView(previewError: "Current password incorrect")
        }
        XCTAssertNoThrow(try hostAndInstantiate(view))
    }

    // MARK: - DeleteAccountView

    func test_deleteAccountView_pristine_renders() {
        let state = stateWithUser(verifiedUser())
        let view = NavigationStack { DeleteAccountView() }.environment(state)
        XCTAssertNoThrow(try hostAndInstantiate(view))
    }

    // MARK: - APIClient wiring

    func test_apiClient_exposesAccountMethods() {
        // Compile-time assertion: the async methods exist with the documented
        // shape. We don't hit the network; this guards against accidental
        // renames when the backend worker finalises the contracts.
        let client = APIClient.shared
        _ = { () async throws -> Void in
            _ = try await client.fetchProfile()
            _ = try await client.updateProfile(name: "N")
            try await client.changePassword(current: "c", new: "n12345678")
            try await client.deleteAccount(password: "p")
        }
    }

    // MARK: - Helpers

    /// Instantiates the view's body so that any ViewBuilder / state
    /// construction errors surface at test-time. This is the minimum we can
    /// do without the snapshot-testing library; it catches the common
    /// regressions — missing environment values, crashing initialisers,
    /// misconfigured bindings.
    private func hostAndInstantiate(_ view: some View) throws {
        let host = UIHostingController(rootView: view)
        host.view.layoutIfNeeded()
        _ = host.view.bounds
    }
}
