import XCTest
@testable import BowPress

@MainActor
final class EndSessionPlotsBySessionTests: XCTestCase {

    /// Regression: ppc750's empty-Log-tab fix (issue #4) hoisted plotsBySession
    /// from view-state into AppState and replaced the in-view `.onAppear` refresh
    /// with a seed inside `SessionViewModel.onSessionCompleted`. The seed reads
    /// arrows from a sibling closure parameter rather than `completed.arrows`
    /// (which is `nil` per `ShootingSession`'s strip-arrows convention).
    /// If a future refactor reverts the callback signature back to a
    /// single-argument shape — or sources arrows from `completed.arrows` —
    /// the just-finished session's bars will go gray on the Log tab until
    /// next cold launch. This test catches that.
    func test_endSession_callbackPassesArrowsAsSiblingArg() async {
        let viewModel = SessionViewModel(apiClient: MockAPIClient(), store: nil)
        viewModel.currentSession = ShootingSession(
            id: "test_session",
            bowId: "b1",
            bowConfigId: "bc1",
            arrowConfigId: "ac1",
            startedAt: Date(),
            endedAt: nil,
            notes: "",
            feelTags: [],
            arrowCount: 0,
            targetFaceType: .tenRing
        )
        viewModel.allArrows = SnapshotTestHelpers.makePlots(
            sessionId: "test_session", count: 6
        )

        var capturedSession: ShootingSession?
        var capturedArrows: [ArrowPlot]?
        viewModel.onSessionCompleted = { session, arrows in
            capturedSession = session
            capturedArrows = arrows
        }

        await viewModel.endSession()

        XCTAssertEqual(capturedSession?.id, "test_session",
                       "callback should pass the completed session DTO")
        XCTAssertEqual(capturedArrows?.count, 6,
                       "callback should pass allArrows as a sibling parameter")
        XCTAssertNil(capturedSession?.arrows,
                     "completed.arrows should remain nil per the strip-arrows convention")
    }
}
