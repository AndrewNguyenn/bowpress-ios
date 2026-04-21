import XCTest
import StoreKitTest

/// Covers the two paywall flows that can't run via Maestro + simctl launch
/// (Apple doesn't honor scheme-attached StoreKit configs in that path, and
/// `SKTestSession` isn't loadable from an app target). Running them inside
/// a UI test bundle gets the `XCTest` + `StoreKitTest` frameworks the
/// bundle needs, and lets us wire `SKTestSession` programmatically from
/// the test runner.
///
/// Prerequisites (set up by scripts/e2e.sh):
/// - `wrangler dev` with `ENVIRONMENT=test` running on localhost:8787
/// - D1 seeded via `npm run seed:e2e:local` so `e2e-free@bowpress.dev`
///   exists and has no active entitlement row.
final class PaywallUITests: XCTestCase {
    private var skSession: SKTestSession!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        // Products.storekit is copied into the test runner's .xctest
        // bundle by a postCompileScripts step in project.yml so `Bundle
        // (for: Self.self)` can find it.
        guard let url = Bundle(for: PaywallUITests.self)
            .url(forResource: "Products", withExtension: "storekit")
        else {
            throw XCTSkip("Products.storekit not in test bundle — is the copy step wired up?")
        }
        skSession = try SKTestSession(contentsOf: url)
        // Reset first — resetToDefaultState() re-applies config defaults,
        // which would clobber the dialog settings if we set them earlier.
        skSession.resetToDefaultState()
        skSession.clearTransactions()
        skSession.disableDialogs = true
        skSession.askToBuyEnabled = false
    }

    override func tearDown() async throws {
        skSession = nil
        try await super.tearDown()
    }

    // MARK: - Purchase flow (covers paywall → monthly plan → entitlement active)

    func testPaywallPurchase() throws {
        let app = launched(asEmail: "e2e-free@bowpress.dev")

        // Navigate to Equipment — where the upgrade banner surfaces for
        // unentitled users.
        waitForSplashToClear(app)
        app.tabBars.buttons["Equipment"].tap()

        // UpgradeBanner is rendered as a Button; the monthly plan row is
        // also a Button. The paywall sheet's root View doesn't query
        // reliably as .otherElements across SwiftUI versions, so drive
        // off the buttons directly.
        let banner = app.buttons["upgrade_banner"]
        XCTAssertTrue(
            banner.waitForExistence(timeout: 10),
            "upgrade_banner never appeared — REAL_ENTITLEMENT wiring broken?"
        )
        banner.tap()

        // StoreKit products from Products.storekit should resolve via the
        // SKTestSession bound in setUp. Give the UI a moment to bind.
        let monthly = app.buttons["paywall_monthly_button"]
        XCTAssertTrue(
            monthly.waitForExistence(timeout: 15),
            "paywall_monthly_button never appeared — products didn't load"
        )
        monthly.tap()

        // disableDialogs/askToBuyEnabled means StoreKit auto-approves;
        // backend /subscription/verify fires, entitlement flips active,
        // ReadOnlyGate tears down the sheet + banner.
        XCTAssertTrue(waitForNonExistence(banner, timeout: 15),
                      "upgrade banner never dismissed after purchase")
    }

    // MARK: - Lapsed subscription (covers re-purchase after entitlement expires)

    func testLapsedSubscriptionRecovers() throws {
        // Force the e2e-free user's entitlement inactive on the backend via
        // the test-only route (gated behind ENVIRONMENT=test in wrangler).
        try forceEntitlement(active: false, for: "e2e-free@bowpress.dev")

        let app = launched(asEmail: "e2e-free@bowpress.dev")
        waitForSplashToClear(app)

        let banner = app.buttons["upgrade_banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10),
                      "upgrade_banner missing despite PATCH /__test__/entitlement isActive=false")
        banner.tap()

        let monthly = app.buttons["paywall_monthly_button"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 15),
                      "paywall_monthly_button never appeared — products didn't load")
        monthly.tap()

        XCTAssertTrue(waitForNonExistence(banner, timeout: 15),
                      "upgrade banner still visible after re-purchase")
    }

    // MARK: - Helpers

    private func launched(asEmail email: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AutoSignInEmail", email, "-AutoSignInPassword", "bowpress-e2e-pw-1234"]
        app.launchEnvironment["REAL_ENTITLEMENT"] = "1"
        app.launchEnvironment["USE_LOCAL_API"] = "1"
        app.launchEnvironment["API_BASE_URL"] =
            ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:8787"
        app.launch()
        return app
    }

    private func waitForSplashToClear(_ app: XCUIApplication) {
        let splash = app.staticTexts["Analyzing your data"]
        if splash.exists {
            XCTAssertTrue(waitForNonExistence(splash, timeout: 20),
                          "hydration splash never cleared")
        }
        // Tab bar must exist for any subsequent tap to land on app content.
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    }

    private func waitForNonExistence(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func forceEntitlement(active: Bool, for email: String) throws {
        let base = ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:8787"
        var req = URLRequest(url: URL(string: "\(base)/__test__/entitlement")!)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(
            withJSONObject: ["email": email, "isActive": active]
        )
        let expectation = self.expectation(description: "PATCH /__test__/entitlement")
        URLSession.shared.dataTask(with: req) { _, response, _ in
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                XCTFail("Failed to force entitlement for \(email)")
                expectation.fulfill()
                return
            }
            expectation.fulfill()
        }.resume()
        wait(for: [expectation], timeout: 5)
    }
}
