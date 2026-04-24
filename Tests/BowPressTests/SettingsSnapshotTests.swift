import XCTest
import SwiftUI
import SnapshotTesting
@testable import BowPress

#if canImport(UIKit)
import UIKit

// MARK: - SettingsSnapshotTests
//
// Image snapshots of the Kenrokuen Settings surface. Previously this file only
// performed compile/instantiation checks; it is now wired to swift-snapshot-
// testing so palette and typography regressions surface as pixel diffs.
//
// Covered variants:
//   • SettingsView         — populated verified user
//   • AccountView          — verified badge / unverified badge
//   • EditProfileView      — pristine (save button disabled until name changes)
//   • ChangePasswordView   — pristine + error state
//   • DeleteAccountView    — pristine

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
        state.isHydrating = false
        return state
    }

    // MARK: - SettingsView

    func testSettingsView_populatedVerifiedUser() {
        let state = stateWithUser(verifiedUser())
        let view = NavigationStack { SettingsView() }.environment(state)
        assertSnapshot(
            of: SnapshotTestHelpers.snaphost(view),
            as: .image(on: .iPhone13),
            record: false
        )
    }

    // MARK: - AccountView

    func testAccountView_verifiedUser_showsVerifiedBadge() {
        let state = stateWithUser(verifiedUser())
        let view = NavigationStack { AccountView() }.environment(state)
        assertSnapshot(
            of: SnapshotTestHelpers.snaphost(view),
            as: .image(on: .iPhone13),
            record: false
        )
    }

    func testAccountView_unverifiedUser_showsUnverifiedBadge() {
        let state = stateWithUser(unverifiedUser())
        let view = NavigationStack { AccountView() }.environment(state)
        assertSnapshot(
            of: SnapshotTestHelpers.snaphost(view),
            as: .image(on: .iPhone13),
            record: false
        )
    }

    // MARK: - EditProfileView

    func testEditProfileView_pristine() {
        let state = stateWithUser(verifiedUser())
        let view = NavigationStack { EditProfileView() }.environment(state)
        assertSnapshot(
            of: SnapshotTestHelpers.snaphost(view),
            as: .image(on: .iPhone13),
            record: false
        )
    }

    // MARK: - ChangePasswordView

    func testChangePasswordView_pristine() {
        let view = NavigationStack { ChangePasswordView() }
        assertSnapshot(
            of: SnapshotTestHelpers.snaphost(view),
            as: .image(on: .iPhone13),
            record: false
        )
    }

    func testChangePasswordView_withError() {
        let view = NavigationStack {
            ChangePasswordView(previewError: "Current password incorrect")
        }
        assertSnapshot(
            of: SnapshotTestHelpers.snaphost(view),
            as: .image(on: .iPhone13),
            record: false
        )
    }

    // MARK: - DeleteAccountView

    func testDeleteAccountView_pristine() {
        let state = stateWithUser(verifiedUser())
        let view = NavigationStack { DeleteAccountView() }.environment(state)
        assertSnapshot(
            of: SnapshotTestHelpers.snaphost(view),
            as: .image(on: .iPhone13),
            record: false
        )
    }
}

#endif
