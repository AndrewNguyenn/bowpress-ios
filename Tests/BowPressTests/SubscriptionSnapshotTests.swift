import XCTest
import SwiftUI
#if canImport(SnapshotTesting)
import SnapshotTesting
#endif
@testable import BowPress

#if canImport(UIKit)
import UIKit

@MainActor
final class SubscriptionSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // isRecording = false
    }

    // MARK: - PaywallView

    func testPaywallView_loading() {
        let view = PaywallView()
            .environment(AppState())
            .frame(width: 390, height: 844)
        assertSnapshot(of: UIHostingController(rootView: view), as: .image)
    }

    func testPaywallView_error() {
        SubscriptionManager.shared.lastError = "Could not load plans"
        SubscriptionManager.shared.products = []
        let view = PaywallView()
            .environment(AppState())
            .frame(width: 390, height: 844)
        assertSnapshot(of: UIHostingController(rootView: view), as: .image)
        SubscriptionManager.shared.lastError = nil
    }

    // Note: a "loaded" snapshot requires live StoreKit products, which cannot be
    // constructed in a unit test without a running StoreKit session. The paywall's
    // `products.isEmpty` branch already covers the empty-state rendering, and the
    // per-product row layout is exercised via the `ProductRow` hierarchy.

    // MARK: - SubscriptionStatusCard

    func testStatusCard_activeMonthly() {
        let e = Entitlement(
            isActive: true,
            inTrial: false,
            provider: "apple",
            productId: BowPressProduct.monthly,
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000),
            autoRenew: true
        )
        assertSnapshot(of: hosting(SubscriptionStatusCard(entitlement: e)), as: .image)
    }

    func testStatusCard_activeAnnual() {
        let e = Entitlement(
            isActive: true,
            inTrial: false,
            provider: "apple",
            productId: BowPressProduct.annual,
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000),
            autoRenew: true
        )
        assertSnapshot(of: hosting(SubscriptionStatusCard(entitlement: e)), as: .image)
    }

    func testStatusCard_trial() {
        let e = Entitlement(
            isActive: true,
            inTrial: true,
            provider: "apple",
            productId: BowPressProduct.monthly,
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000),
            autoRenew: true
        )
        assertSnapshot(of: hosting(SubscriptionStatusCard(entitlement: e)), as: .image)
    }

    func testStatusCard_expired_rendersEmpty() {
        // Safety: the card must render no visible content when `isActive == false`.
        let e = Entitlement.inactive
        assertSnapshot(of: hosting(SubscriptionStatusCard(entitlement: e)), as: .image)
    }

    // MARK: - Helpers

    private func hosting<V: View>(_ view: V) -> UIHostingController<AnyView> {
        let wrapped = AnyView(
            view
                .frame(width: 360)
                .padding()
                .background(Color.appBackground)
        )
        let host = UIHostingController(rootView: wrapped)
        host.view.frame = CGRect(x: 0, y: 0, width: 360, height: 240)
        return host
    }
}

#endif
