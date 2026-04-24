import XCTest
import SwiftUI
import SnapshotTesting
@testable import BowPress

#if canImport(UIKit)
import UIKit

// MARK: - AnalyticsSnapshotTests
//
// Three variants of the Kenrokuen Analytics screen:
//   (a) empty state  — viewModel has no overview (sessionCount = 0)
//   (b) mature data, comparison-up  — current period avg > previous (positive delta)
//   (c) mature data, comparison-down — current period avg < previous (negative delta)
//
// The AnalyticsView.init(testViewModel:) DEBUG initialiser injects the pre-built
// AnalyticsViewModel so the network load path is bypassed entirely.

@MainActor
final class AnalyticsSnapshotTests: XCTestCase {

    private var store: LocalStore!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        store = SnapshotTestHelpers.makeInMemoryStore()
        appState = AppState()
        // AppState in DEBUG already carries DevMockData bows + arrows; that's fine.
        appState.isHydrating = false
    }

    // MARK: - (a) Empty state

    func testAnalytics_emptyState() {
        let vm = AnalyticsViewModel()
        // overview.sessionCount == 0 → emptyStateView renders (same as nil path
        // visually). Using a zero-session overview (rather than nil) so that
        // initialLoad()'s `guard overview == nil` fires and the async .task does
        // NOT call store.fetchSessions() — which would crash in an in-memory store.
        vm.overview = AnalyticsOverview(
            period: .week,
            sessionCount: 0,
            avgArrowScore: 0,
            xPercentage: 0,
            suggestions: []
        )
        assertSnapshot(
            of: snaphost(AnalyticsView(testViewModel: vm)),
            as: .image(on: .iPhone13),
            record: false
        )
    }

    // MARK: - (b) Mature data — comparison-up (positive delta)

    func testAnalytics_matureData_comparisonUp() {
        let vm = matureViewModel(comparisonUp: true)
        assertSnapshot(
            of: snaphost(AnalyticsView(testViewModel: vm)),
            as: .image(on: .iPhone13),
            record: false
        )
    }

    // MARK: - (c) Mature data — comparison-down (negative delta)

    func testAnalytics_matureData_comparisonDown() {
        let vm = matureViewModel(comparisonUp: false)
        assertSnapshot(
            of: snaphost(AnalyticsView(testViewModel: vm)),
            as: .image(on: .iPhone13),
            record: false
        )
    }

    // MARK: - Fixture builders

    /// Returns an `AnalyticsViewModel` pre-loaded with mock data.
    /// `comparisonUp = true` → current avg > previous (green delta).
    /// `comparisonUp = false` → current avg < previous (red delta).
    private func matureViewModel(comparisonUp: Bool) -> AnalyticsViewModel {
        let vm = AnalyticsViewModel()
        let overview = DevMockData.overview(period: .week)
        vm.overview = overview
        vm.suggestions = overview.suggestions
        vm.timeline  = MockAnalyticsWave2.timeline(period: .week)
        vm.drift     = MockAnalyticsWave2.drift(period: .week)
        vm.trends    = MockAnalyticsWave2.trends(period: .week)
        vm.comparison = comparisonUp
            ? DevMockData.comparison(period: .week)   // cur 10.6, prev 9.4 → +1.2
            : makeComparisonDown()
        return vm
    }

    /// Constructs a `PeriodComparison` where the current period average is
    /// lower than the previous — triggering the maple (red) delta tint.
    private func makeComparisonDown() -> PeriodComparison {
        let cur = PeriodSlice(
            label: "This week",
            plots: SnapshotTestHelpers.makePlots(sessionId: "snap_cur", count: 12),
            avgArrowScore: 9.2,
            xPercentage: 17,
            sessionCount: 3,
            config: nil,
            centroid: Centroid(x: 0.02, y: 0.04),
            sigma: SigmaEllipse(major: 0.14, minor: 0.10, rotationDeg: 10)
        )
        let prev = PeriodSlice(
            label: "Last week",
            plots: SnapshotTestHelpers.makePlots(sessionId: "snap_prv", count: 18),
            avgArrowScore: 10.4,
            xPercentage: 56,
            sessionCount: 4,
            config: nil,
            centroid: Centroid(x: -0.05, y: 0.03),
            sigma: SigmaEllipse(major: 0.18, minor: 0.12, rotationDeg: -15)
        )
        return PeriodComparison(
            period: .week,
            current: cur,
            previous: prev,
            shift: ShiftVector(dxMm: -7, dyMm: -3, direction: "left · down", description: "left · down · away from center")
        )
    }

    // MARK: - Host helper

    private func snaphost(_ view: AnalyticsView) -> UIViewController {
        let wrapped = NavigationStack { view }
            .environment(appState)
            .environment(store)
        return SnapshotTestHelpers.snaphost(wrapped)
    }
}

#endif
