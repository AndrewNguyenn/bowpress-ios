import XCTest
import SwiftUI
import SnapshotTesting
@testable import BowPress

#if canImport(UIKit)
import UIKit

// MARK: - LogSnapshotTests
//
// Kenrokuen Session Log screen (HistoricalSessionsView) snapshot:
//   • 3 week-based groups: "This week", "Last week", and a monthly bucket
//   • Top-of-group session stamped BEST (ss1 — highest avg in the corpus)
//   • Month heatmap (monthbox) inserted between Last week and the monthly group
//
// `ShootingSession.mockSessions` (defined in HistoricalSessionsView.swift)
// provides 8 sessions spanning ~24 days — exactly the fixture we need.

@MainActor
final class LogSnapshotTests: XCTestCase {

    // MARK: - 3 groups + BEST stamp + month heatmap

    func testLog_threeWeekGroups_bestStampAndMonthRollup() {
        let sessions = ShootingSession.mockSessions  // 8 sessions, ~24 days span

        let view = NavigationStack {
            HistoricalSessionsView(
                sessions: sessions,
                bowName: "All Bows",
                allConfigs: []
            )
        }
        .environment(AppState())

        assertSnapshot(
            of: SnapshotTestHelpers.snaphost(view),
            as: .image(on: .iPhone13),
            record: false
        )
    }
}

#endif
