import Foundation
import Observation

@Observable @MainActor
final class AnalyticsViewModel {
    static let bowTypeDefaultsKey = "analytics.selectedBowType"

    var selectedPeriod: AnalyticsPeriod = .threeDays
    /// nil = "All bows" (default).
    var selectedBowType: BowType? = {
        guard let raw = UserDefaults.standard.string(forKey: AnalyticsViewModel.bowTypeDefaultsKey) else { return nil }
        return BowType(rawValue: raw)
    }()
    var overview: AnalyticsOverview?
    var comparison: PeriodComparison?
    var suggestions: [AnalyticsSuggestion] = []
    var extraInsights: [TrendInsight] = []
    var isLoading: Bool = false
    var error: String?

    private var engine: LocalAnalyticsEngine?
    private var appState: AppState?
    private var localStore: LocalStore?
    /// Optional override for tests; when nil we route through `APIClient.shared`.
    private var apiClient: BowPressAPIClient?

    /// Test-only setter so unit tests can inject a `MockAPIClient` without
    /// touching production singleton wiring. Not @MainActor by accident —
    /// the whole class is.
    func _setAPIClient(_ client: BowPressAPIClient) {
        self.apiClient = client
    }

    private var client: BowPressAPIClient { apiClient ?? APIClient.shared }

    func configure(store: LocalStore) {
        engine = LocalAnalyticsEngine(store: store)
        localStore = store
    }

    func configure(store: LocalStore, appState: AppState) {
        engine = LocalAnalyticsEngine(store: store)
        self.appState = appState
        localStore = store
    }

    // MARK: - Public API

    func selectBowType(_ type: BowType?) async {
        guard type != selectedBowType else { return }
        selectedBowType = type
        if let type {
            UserDefaults.standard.set(type.rawValue, forKey: Self.bowTypeDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.bowTypeDefaultsKey)
        }
        await load(period: selectedPeriod)
    }

    func load(period: AnalyticsPeriod) async {
        guard !isLoading, let engine else { return }
        selectedPeriod = period
        isLoading = true
        error = nil
        do {
            overview = try engine.overview(period: period, bowType: selectedBowType)
            comparison = try engine.comparison(period: period, bowType: selectedBowType)
            extraInsights = (try? engine.multiSessionInsights()) ?? []
            let readIds = Set(suggestions.filter(\.wasRead).map(\.id))
            // Carry over any locally-applied state too — the server is the
            // source of truth for `wasApplied` once it round-trips, but we
            // optimistically flip it in memory before the network finishes.
            let appliedIds = Set(suggestions.filter(\.wasApplied).map(\.id))
            var all: [AnalyticsSuggestion] = []
            if let appState {
                for bow in appState.bows {
                    let list = (try? await APIClient.shared.fetchSuggestions(bowId: bow.id)) ?? []
                    all.append(contentsOf: list)
                }
            } else {
                all = (try? await APIClient.shared.fetchSuggestions()) ?? []
            }
            // Dedupe by id — the per-bow API is currently a stub that returns the full
            // list regardless of bowId, so iterating over N bows yields N copies of
            // every suggestion. Keep this even after the API is properly scoped, since
            // a suggestion id should always be unique across the visible set.
            var seen = Set<String>()
            suggestions = all.compactMap { s in
                guard seen.insert(s.id).inserted else { return nil }
                var copy = s
                if readIds.contains(s.id) { copy.wasRead = true }
                if appliedIds.contains(s.id) { copy.wasApplied = true }
                return copy
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        await load(period: selectedPeriod)
    }

    func markRead(_ suggestion: AnalyticsSuggestion) async {
        guard !suggestion.wasRead else { return }
        if let idx = suggestions.firstIndex(where: { $0.id == suggestion.id }) {
            suggestions[idx].wasRead = true
        }
        try? await APIClient.shared.markSuggestionRead(id: suggestion.id)
    }

    /// Permanently dismiss a suggestion. Optimistically removes it from the visible
    /// list, fires the API call; on failure, restores it at its original position.
    /// The backend analytics pipeline's novelty gate already respects `wasDismissed`.
    func dismiss(_ suggestion: AnalyticsSuggestion) async {
        guard let idx = suggestions.firstIndex(where: { $0.id == suggestion.id }) else { return }
        let removed = suggestions.remove(at: idx)
        do {
            try await APIClient.shared.dismissSuggestion(id: suggestion.id)
        } catch {
            // Re-insert at original index on failure so the user's view reconciles.
            let insertAt = min(idx, suggestions.count)
            suggestions.insert(removed, at: insertAt)
            self.error = error.localizedDescription
        }
    }

    /// Apply a suggestion: optimistically flips wasApplied locally so the row
    /// re-sorts to the bottom + shows its "Applied" badge instantly, then
    /// fires the server call. On success, persists the new BowConfiguration
    /// to LocalStore and bumps the analytics refresh nonce; on failure,
    /// reverts the optimistic change and surfaces `error`.
    @discardableResult
    func apply(_ suggestion: AnalyticsSuggestion) async throws -> BowConfiguration {
        guard let idx = suggestions.firstIndex(where: { $0.id == suggestion.id }) else {
            throw URLError(.fileDoesNotExist)
        }
        // Snapshot original so we can revert on failure.
        let original = suggestions[idx]
        suggestions[idx].wasApplied = true
        suggestions[idx].appliedAt = Date()

        do {
            let result = try await client.applySuggestion(bowId: suggestion.bowId, id: suggestion.id)
            // Reconcile with server-truth (id of new config, exact appliedAt).
            if let i = suggestions.firstIndex(where: { $0.id == suggestion.id }) {
                suggestions[i] = result.suggestion
            }
            // Persist new config locally so BowDetailView's config list shows
            // it without a network round-trip.
            try? localStore?.save(config: result.newConfig)
            // Tell other tabs to refresh.
            appState?.analyticsRefreshNonce += 1
            appState?.bowConfigsRefreshNonce += 1
            return result.newConfig
        } catch {
            // Revert optimistic flip; surface error.
            if let i = suggestions.firstIndex(where: { $0.id == suggestion.id }) {
                suggestions[i] = original
            }
            self.error = error.localizedDescription
            throw error
        }
    }
}
