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

    // MARK: - SubscriptionStatusCard

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
