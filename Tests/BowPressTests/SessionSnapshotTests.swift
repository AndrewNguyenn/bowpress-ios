import XCTest
import SwiftUI
import SnapshotTesting
@testable import BowPress

#if canImport(UIKit)
import UIKit

// MARK: - SessionSnapshotTests
//
// Three variants of the Kenrokuen Session screen:
//   (a) Setup   — pre-session form with 50 m distance + 10-ring face selected
//   (b) Active  —  3 arrows plotted on the target
//   (c) Active  — 16 arrows plotted on the target
//
// SessionView.init(testViewModel:selectedDistance:selectedFaceType:) is the
// DEBUG initialiser that pins the selection state before .onAppear priming.

@MainActor
final class SessionSnapshotTests: XCTestCase {

    private var store: LocalStore!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        store = SnapshotTestHelpers.makeInMemoryStore()
        appState = AppState()
        appState.isHydrating = false
        // Ensure bows + arrows are populated (DEBUG AppState already includes DevMockData).
        if appState.bows.isEmpty {
            appState.bows = [DevMockData.bow1]
            appState.arrowConfigs = [DevMockData.arrow1]
        }
    }

    // MARK: - (a) Setup — 50 m + 10-ring selected

    func testSession_setup_50m_10ring() {
        let vm = SessionViewModel()
        vm.selectedBow = appState.bows.first
        // Skip LocalStore fetches in primeSetupState() — calling context.fetch()
        // from within the snapshot render path crashes the in-memory SwiftData store.
        vm.isSnapshotTest = true

        assertSnapshot(
            of: snaphost(
                SessionView(
                    appState: appState,
                    viewModel: vm,
                    selectedDistance: .fiftyMeters,
                    selectedFaceType: .tenRing
                )
            ),
            as: .image(on: .iPhone13),
            record: false
        )
    }

    // MARK: - (b) Active — 3 arrows

    func testSession_active_3arrows() {
        let vm = activeViewModel(arrowCount: 3)
        assertSnapshot(
            of: snaphost(SessionView(appState: appState, viewModel: vm)),
            as: .image(on: .iPhone13),
            record: false
        )
    }

    // MARK: - (c) Active — 16 arrows

    func testSession_active_16arrows() {
        let vm = activeViewModel(arrowCount: 16)
        assertSnapshot(
            of: snaphost(SessionView(appState: appState, viewModel: vm)),
            as: .image(on: .iPhone13),
            record: false
        )
    }

    // MARK: - Fixture builder

    // Fixed "now" matching SessionView's DEBUG init default (2025-01-01 00:00 UTC).
    private static let mockNow = Date(timeIntervalSince1970: 1_735_689_600)

    private func activeViewModel(arrowCount: Int) -> SessionViewModel {
        let bow    = DevMockData.bow1
        let bowCfg = BowConfiguration.makeDefault(for: bow)
        let arrow  = DevMockData.arrow1

        let vm = SessionViewModel()
        vm.isSessionActive   = true
        vm.isSnapshotTest    = true
        vm.selectedBow       = bow
        vm.activeBowConfig   = bowCfg
        vm.activeArrowConfig = arrow
        vm.currentSession = ShootingSession(
            id: "snap_session",
            bowId: bow.id,
            bowConfigId: bowCfg.id,
            arrowConfigId: arrow.id,
            // Fixed startedAt: 20 min before mockNow so elapsed timer shows "20:00"
            startedAt: Self.mockNow.addingTimeInterval(-1200),
            endedAt: nil,
            notes: "",
            feelTags: [],
            arrowCount: 0,
            targetFaceType: .tenRing,
            distance: .fiftyMeters
        )
        vm.allArrows = SnapshotTestHelpers.makePlots(sessionId: "snap_session", count: arrowCount)
        return vm
    }

    // MARK: - Host helper

    private func snaphost(_ view: SessionView) -> UIViewController {
        let wrapped = NavigationStack { view }
            .environment(appState)
            .environment(store)
        return SnapshotTestHelpers.snaphost(wrapped)
    }
}

#endif
