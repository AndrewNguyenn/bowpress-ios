import Foundation
import SwiftUI
import SwiftData
@testable import BowPress

#if canImport(UIKit)
import UIKit

// MARK: - SnapshotTestHelpers
//
// Shared utilities for all BowPress snapshot tests. Provides:
//   • makeInMemoryStore()  – an empty LocalStore backed by an in-memory
//     SwiftData container so views that @Environment(LocalStore.self) can
//     render without touching disk or requiring seeded data.
//   • snaphost(_:)         – wraps a SwiftUI view in a UIHostingController
//     sized to a portrait iPhone screen, ready for assertSnapshot(…).

@MainActor
enum SnapshotTestHelpers {

    // MARK: - In-memory LocalStore

    /// Returns a `LocalStore` backed by a fully in-memory SwiftData container.
    /// Suitable for tests that need the environment object present but don't
    /// actually read from it during the snapshot render.
    static func makeInMemoryStore() -> LocalStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: PersistentBow.self,
                PersistentBowConfig.self,
                PersistentArrowConfig.self,
                PersistentSession.self,
                PersistentArrowPlot.self,
                PersistentEnd.self,
                PersistentSuggestion.self,
            configurations: config
        )
        return LocalStore(context: container.mainContext)
    }

    // MARK: - UIHostingController factory

    /// Wraps `view` in a `UIHostingController` with a fixed iPhone 13–sized
    /// frame (390 × 844 pt, light mode). Pass the result to
    /// `assertSnapshot(of:as:)` with the `.image` or `.image(on:)` strategy.
    static func snaphost<V: View>(_ view: V) -> UIViewController {
        let host = UIHostingController(rootView: AnyView(view))
        host.overrideUserInterfaceStyle = .light
        // iPhone 13 logical resolution
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.layoutIfNeeded()
        return host
    }

    // MARK: - Arrow fixture builder

    /// Builds `count` `ArrowPlot` objects with cycling rings/zones, all tagged
    /// to `sessionId`. Useful for populating `SessionViewModel.allArrows`.
    static func makePlots(sessionId: String, count: Int) -> [ArrowPlot] {
        let rings =  [11, 10, 11, 10, 9, 10, 11, 10, 9, 10, 11, 10, 9, 10, 11, 10]
        let zones: [ArrowPlot.Zone] = [.center, .n, .center, .ne, .center, .n, .center, .center,
                                       .center, .ne, .center, .n, .center, .center, .n, .center]
        let plotXs: [Double] = [ 0.020,  0.012, -0.008,  0.025, -0.015,  0.018,  0.030, -0.010,
                                  0.022, -0.018,  0.010,  0.028, -0.012,  0.015, -0.020,  0.008]
        let plotYs: [Double] = [ 0.025,  0.090,  0.030,  0.100,  0.085,  0.022,  0.018,  0.092,
                                  0.028,  0.080,  0.035,  0.015,  0.095,  0.020,  0.088,  0.032]
        return (0..<count).map { i in
            ArrowPlot(
                id: "\(sessionId)_a\(i + 1)",
                sessionId: sessionId,
                bowConfigId: "snap_bc1",
                arrowConfigId: "snap_ac1",
                ring: rings[i % rings.count],
                zone: zones[i % zones.count],
                plotX: plotXs[i % plotXs.count],
                plotY: plotYs[i % plotYs.count],
                shotAt: Date().addingTimeInterval(Double(i) * 60),
                excluded: false,
                notes: nil
            )
        }
    }
}

#endif
