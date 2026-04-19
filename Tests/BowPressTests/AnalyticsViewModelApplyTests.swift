import XCTest
import SwiftData
@testable import BowPress

@MainActor
final class AnalyticsViewModelApplyTests: XCTestCase {

    /// Build an isolated in-memory SwiftData store for each test. Tests
    /// share the host app process, so they must NOT touch the app's
    /// container — each test gets its own throwaway store and ModelContext.
    private func makeStore() throws -> LocalStore {
        let schema = Schema([
            PersistentBow.self, PersistentBowConfig.self, PersistentArrowConfig.self,
            PersistentSession.self, PersistentArrowPlot.self, PersistentEnd.self,
            PersistentSuggestion.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return LocalStore(context: ModelContext(container))
    }

    private func makeSuggestion(applied: Bool = false) -> AnalyticsSuggestion {
        AnalyticsSuggestion(
            id: "sug-test",
            bowId: "bow-test",
            createdAt: Date(),
            parameter: "restVertical",
            suggestedValue: "11",
            currentValue: "10",
            reasoning: "test",
            confidence: 0.85,
            qualifier: nil,
            wasRead: true,
            wasDismissed: false,
            deliveryType: .inApp,
            wasApplied: applied
        )
    }

    private func makeNewConfig() -> BowConfiguration {
        BowConfiguration(
            id: "cfg-new",
            bowId: "bow-test",
            createdAt: Date(),
            label: "Auto-applied: restVertical",
            drawLength: 28.5,
            restVertical: 11,
            restHorizontal: 10,
            restDepth: 0,
            gripAngle: 0,
            nockingHeight: 0,
            isReference: false,
            scoreable: false
        )
    }

    func test_apply_happyPath_marksAppliedAndPersistsConfig() async throws {
        let vm = AnalyticsViewModel()
        let store = try makeStore()
        let appState = AppState()
        vm.configure(store: store, appState: appState)

        let mock = MockAPIClient()
        let suggestion = makeSuggestion()
        let newCfg = makeNewConfig()
        var applyCallCount = 0
        mock.applySuggestionImpl = { bowId, id in
            applyCallCount += 1
            XCTAssertEqual(bowId, suggestion.bowId)
            XCTAssertEqual(id, suggestion.id)
            var applied = suggestion
            applied.wasApplied = true
            applied.appliedAt = Date()
            applied.appliedConfigId = newCfg.id
            return ApplyResult(suggestion: applied, newConfig: newCfg)
        }
        vm._setAPIClient(mock)
        vm.suggestions = [suggestion]
        let nonceBefore = appState.analyticsRefreshNonce
        let configsNonceBefore = appState.bowConfigsRefreshNonce

        let result = try await vm.apply(suggestion)

        XCTAssertEqual(applyCallCount, 1)
        XCTAssertEqual(result.id, newCfg.id)
        XCTAssertTrue(vm.suggestions[0].wasApplied)
        XCTAssertEqual(vm.suggestions[0].appliedConfigId, newCfg.id)
        XCTAssertEqual(appState.analyticsRefreshNonce, nonceBefore + 1)
        XCTAssertEqual(appState.bowConfigsRefreshNonce, configsNonceBefore + 1)

        // Persisted to LocalStore so other tabs can read it.
        let persisted = try store.fetchConfigurations(bowId: "bow-test")
        XCTAssertTrue(persisted.contains { $0.id == newCfg.id })
    }

    func test_apply_failure_revertsOptimisticFlipAndSurfacesError() async throws {
        let vm = AnalyticsViewModel()
        let store = try makeStore()
        let appState = AppState()
        vm.configure(store: store, appState: appState)

        let mock = MockAPIClient()
        let suggestion = makeSuggestion()
        struct AppError: Error, LocalizedError { var errorDescription: String? { "boom" } }
        mock.applySuggestionImpl = { _, _ in throw AppError() }
        vm._setAPIClient(mock)
        vm.suggestions = [suggestion]
        let nonceBefore = appState.analyticsRefreshNonce

        do {
            _ = try await vm.apply(suggestion)
            XCTFail("Expected throw")
        } catch {
            // expected
        }

        XCTAssertFalse(vm.suggestions[0].wasApplied, "optimistic flip should be reverted")
        XCTAssertNil(vm.suggestions[0].appliedConfigId)
        XCTAssertEqual(appState.analyticsRefreshNonce, nonceBefore, "no nonce bump on failure")
        XCTAssertNotNil(vm.error)
        XCTAssertEqual(vm.error, "boom")

        // Nothing persisted.
        let persisted = try store.fetchConfigurations(bowId: "bow-test")
        XCTAssertTrue(persisted.isEmpty)
    }

    func test_visibleSuggestions_sortsAppliedToBottom() {
        let pendingHi = AnalyticsSuggestion(
            id: "p-hi", bowId: "b", createdAt: Date(),
            parameter: "x", suggestedValue: "1", currentValue: "0",
            reasoning: "", confidence: 0.9, wasRead: true,
            deliveryType: .inApp
        )
        let pendingLo = AnalyticsSuggestion(
            id: "p-lo", bowId: "b", createdAt: Date(),
            parameter: "x", suggestedValue: "1", currentValue: "0",
            reasoning: "", confidence: 0.6, wasRead: true,
            deliveryType: .inApp
        )
        let appliedHi = AnalyticsSuggestion(
            id: "a-hi", bowId: "b", createdAt: Date(),
            parameter: "x", suggestedValue: "1", currentValue: "0",
            reasoning: "", confidence: 0.95, wasRead: true,
            deliveryType: .inApp,
            wasApplied: true
        )
        let section = AnalyticsSuggestionsSection(
            suggestions: [appliedHi, pendingLo, pendingHi]
        )
        let order = section.visibleSuggestions.map(\.id)
        XCTAssertEqual(order, ["p-hi", "p-lo", "a-hi"],
                       "applied rows should fall to the bottom regardless of confidence")
    }
}
