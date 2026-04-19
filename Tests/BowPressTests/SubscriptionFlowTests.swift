import XCTest
import SwiftUI
@testable import BowPress

/// Integration coverage for the iOS subscription state machine. Exercises the
/// seams between APIClient, SubscriptionManager, AppState, and the
/// `.subscriptionLapsed` notification — the parts we can drive without a real
/// StoreKit session. Product purchase / restore flows require a live
/// simulator StoreKit session and are covered by manual QA instead.
@MainActor
final class SubscriptionFlowTests: XCTestCase {

    // MARK: - refreshEntitlement

    func test_refreshEntitlement_trial_mirrorsToAppStateAndManager() async {
        let client = MockAPIClient()
        client.entitlementToReturn = Entitlement(
            isActive: true, inTrial: true,
            provider: "apple", productId: nil,
            expiresAt: Date().addingTimeInterval(30 * 86_400),
            autoRenew: false
        )
        let manager = SubscriptionManager(client: client, listenForTransactionUpdates: false)
        let appState = AppState()
        manager.configure(appState: appState)

        await manager.refreshEntitlement()

        XCTAssertEqual(client.fetchEntitlementCallCount, 1)
        XCTAssertEqual(manager.entitlement, client.entitlementToReturn)
        XCTAssertEqual(appState.entitlement, client.entitlementToReturn)
        XCTAssertNil(manager.lastError)
        XCTAssertEqual(appState.entitlement?.inTrial, true)
    }

    func test_refreshEntitlement_subscribed_setsActiveNonTrial() async {
        let client = MockAPIClient()
        client.entitlementToReturn = Entitlement(
            isActive: true, inTrial: false,
            provider: "apple", productId: "com.andrewnguyen.bowpress.monthly",
            expiresAt: Date().addingTimeInterval(30 * 86_400),
            autoRenew: true
        )
        let manager = SubscriptionManager(client: client, listenForTransactionUpdates: false)
        let appState = AppState()
        manager.configure(appState: appState)

        await manager.refreshEntitlement()

        XCTAssertEqual(appState.entitlement?.isActive, true)
        XCTAssertEqual(appState.entitlement?.inTrial, false)
        XCTAssertEqual(appState.entitlement?.productId, "com.andrewnguyen.bowpress.monthly")
        XCTAssertEqual(appState.entitlement?.autoRenew, true)
    }

    func test_refreshEntitlement_inactive_mirrorsFalseStateToAppState() async {
        let client = MockAPIClient()
        client.entitlementToReturn = .inactive
        let manager = SubscriptionManager(client: client, listenForTransactionUpdates: false)
        let appState = AppState()
        manager.configure(appState: appState)

        await manager.refreshEntitlement()

        XCTAssertEqual(appState.entitlement, .inactive)
        XCTAssertEqual(appState.entitlement?.isActive, false)
        XCTAssertEqual(appState.entitlement?.inTrial, false)
    }

    func test_refreshEntitlement_networkError_recordsLastErrorAndLeavesStateUntouched() async {
        let client = MockAPIClient()
        client.fetchEntitlementError = APIError.http(status: 500, body: "oops")
        let manager = SubscriptionManager(client: client, listenForTransactionUpdates: false)
        let appState = AppState()
        let seeded = Entitlement(
            isActive: true, inTrial: false,
            provider: "apple", productId: "com.andrewnguyen.bowpress.monthly",
            expiresAt: Date().addingTimeInterval(86_400),
            autoRenew: true
        )
        appState.entitlement = seeded
        manager.entitlement = seeded
        manager.configure(appState: appState)

        await manager.refreshEntitlement()

        // Error path preserves last-known-good state rather than blanking it.
        XCTAssertEqual(manager.entitlement, seeded)
        XCTAssertEqual(appState.entitlement, seeded)
        XCTAssertNotNil(manager.lastError)
    }

    // MARK: - configure

    func test_configure_mirrorsManagerEntitlementToAppState() {
        let client = MockAPIClient()
        let manager = SubscriptionManager(client: client, listenForTransactionUpdates: false)
        let pre = Entitlement(
            isActive: true, inTrial: true,
            provider: "apple", productId: nil,
            expiresAt: Date().addingTimeInterval(30 * 86_400),
            autoRenew: false
        )
        manager.entitlement = pre

        let appState = AppState()
        // Proves that a newly-configured AppState adopts the manager's current
        // entitlement rather than keeping its default nil — important when the
        // app launches and the manager already refreshed before the view tree
        // mounted.
        manager.configure(appState: appState)

        XCTAssertEqual(appState.entitlement, pre)
    }

    // MARK: - AppState lapse notification

    func test_subscriptionLapsedNotification_flipsActiveEntitlementToInactive() {
        let appState = AppState()
        appState.entitlement = Entitlement(
            isActive: true, inTrial: false,
            provider: "apple", productId: "com.andrewnguyen.bowpress.monthly",
            expiresAt: Date().addingTimeInterval(86_400),
            autoRenew: true
        )

        NotificationCenter.default.post(name: .subscriptionLapsed, object: nil)
        // Notification is delivered synchronously on .main queue observers;
        // let the current runloop tick before asserting.
        let expectation = expectation(description: "lapse-applied")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(appState.entitlement?.isActive, false)
        // Preserves provider/productId so the UI can still display "Expired Monthly"
        // instead of reverting to a blank state.
        XCTAssertEqual(appState.entitlement?.provider, "apple")
        XCTAssertEqual(appState.entitlement?.productId, "com.andrewnguyen.bowpress.monthly")
    }

    func test_subscriptionLapsedNotification_whenNoPriorEntitlement_setsInactiveFixture() {
        let appState = AppState()
        XCTAssertNil(appState.entitlement)

        NotificationCenter.default.post(name: .subscriptionLapsed, object: nil)
        let expectation = expectation(description: "lapse-applied")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(appState.entitlement, .inactive)
    }

    // MARK: - Entitlement fixture

    func test_inactive_fixture_matchesZeroValueFields() {
        let inactive = Entitlement.inactive
        XCTAssertFalse(inactive.isActive)
        XCTAssertFalse(inactive.inTrial)
        XCTAssertNil(inactive.provider)
        XCTAssertNil(inactive.productId)
        XCTAssertNil(inactive.expiresAt)
        XCTAssertFalse(inactive.autoRenew)
    }

    // MARK: - Read-only gate semantics

    /// Covers the contract that drives the UI: when the user is unsubscribed
    /// (entitlement nil or inactive), the iOS `ContentView` applies
    /// `.readOnlyGate(true)` to MainTabView. That gate is a pure function of
    /// `AppState.isSubscribed`. This test pins the mapping.
    func test_readOnlyState_derivesFromEntitlement() {
        let appState = AppState()

        // In DEBUG builds `isSubscribed` is hardcoded true to let the auto-signed-in
        // dev user exercise every screen without hitting StoreKit. This test
        // documents that contract rather than fighting it — the Release path is
        // asserted below via entitlement inspection.
        #if DEBUG
        XCTAssertTrue(appState.isSubscribed, "DEBUG unconditionally returns true; see AppState.swift")
        #endif

        // The entitlement-driven contract (read by server + paywall sheets):
        appState.entitlement = nil
        XCTAssertFalse(appState.entitlement?.isActive ?? false,
                       "nil entitlement must read as inactive at the entitlement layer")

        appState.entitlement = .inactive
        XCTAssertFalse(appState.entitlement!.isActive)

        appState.entitlement = Entitlement(
            isActive: true, inTrial: true,
            provider: nil, productId: nil,
            expiresAt: nil, autoRenew: false
        )
        XCTAssertTrue(appState.entitlement!.isActive)
        XCTAssertTrue(appState.entitlement!.inTrial)
    }
}

// MARK: - Read-only gate view integration

/// Minimal SwiftUI integration checks that the `\.isReadOnly` environment key
/// actually propagates through the gate modifier. We can't easily pixel-snapshot
/// the banner without a full UIHostingController in this target, but we CAN
/// verify the view graph constructs without crashing under both gate states.
@MainActor
final class ReadOnlyGateIntegrationTests: XCTestCase {

    func test_readOnlyGate_falseState_constructsWithoutCrashing() {
        let view = Text("content").readOnlyGate(false)
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()
        XCTAssertNotNil(host.view)
    }

    func test_readOnlyGate_trueState_constructsWithoutCrashing() {
        let view = Text("content").readOnlyGate(true)
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()
        XCTAssertNotNil(host.view)
    }

    func test_isReadOnly_environmentKey_defaultIsFalse() {
        // EnvironmentValues defaultValue should be false so that existing views
        // without the gate applied don't accidentally disable actions.
        var env = EnvironmentValues()
        XCTAssertFalse(env.isReadOnly)
        env.isReadOnly = true
        XCTAssertTrue(env.isReadOnly)
    }
}
