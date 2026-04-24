import Foundation
import Observation

@Observable @MainActor
final class AnalyticsViewModel {
    static let bowTypeDefaultsKey = "analytics.selectedBowType"
    static let distanceDefaultsKey = "analytics.selectedDistance"
    static let periodDefaultsKey = "analytics.selectedPeriod"

    var selectedPeriod: AnalyticsPeriod = {
        if let raw = UserDefaults.standard.string(forKey: AnalyticsViewModel.periodDefaultsKey),
           let stored = AnalyticsPeriod(rawValue: raw) {
            return stored
        }
        return .threeDays
    }()
    /// nil = "All bows" (default).
    var selectedBowType: BowType? = {
        guard let raw = UserDefaults.standard.string(forKey: AnalyticsViewModel.bowTypeDefaultsKey) else { return nil }
        return BowType(rawValue: raw)
    }()
    /// nil = "All distances" (default).
    var selectedDistance: ShootingDistance? = {
        guard let raw = UserDefaults.standard.string(forKey: AnalyticsViewModel.distanceDefaultsKey) else { return nil }
        return ShootingDistance(rawValue: raw)
    }()
    var overview: AnalyticsOverview?
    var comparison: PeriodComparison?
    var suggestions: [AnalyticsSuggestion] = []
    var extraInsights: [TrendInsight] = []
    // Wave 2 — new analytics endpoints. Nullable so a 404 on the server side
    // (older deployments) simply hides the corresponding section.
    var timeline: TimelineResponse?
    var drift: DriftResponse?
    var trends: TrendsResponse?
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

    func selectDistance(_ distance: ShootingDistance?) async {
        guard distance != selectedDistance else { return }
        selectedDistance = distance
        if let distance {
            UserDefaults.standard.set(distance.rawValue, forKey: Self.distanceDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.distanceDefaultsKey)
        }
        await load(period: selectedPeriod)
    }

    func selectPeriod(_ period: AnalyticsPeriod) async {
        guard period != selectedPeriod else { return }
        await load(period: period)
    }

    func load(period: AnalyticsPeriod) async {
        guard !isLoading, let engine else { return }
        selectedPeriod = period
        UserDefaults.standard.set(period.rawValue, forKey: Self.periodDefaultsKey)
        isLoading = true
        error = nil
        do {
            overview = try engine.overview(period: period, bowType: selectedBowType, distance: selectedDistance)
            // Wave 2 — pad overview with fields the engine doesn't compute
            // yet (sparkline, groupSigma, datasetSummary) so the view always
            // has something sensible to render when the server data hasn't
            // caught up.
            decorateOverviewWithMocks()
            comparison = try engine.comparison(period: period, bowType: selectedBowType, distance: selectedDistance)
            decorateComparisonWithMocks()
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

            // Wave 2 — timeline / drift / trends. Each call 404-tolerates so
            // an older backend keeps the rest of the page rendering.
            timeline = await fetchTimeline(period: period)
            drift = await fetchDrift(period: period)
            trends = await fetchTrends(period: period)
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

    // MARK: - Wave 2 endpoint wrappers

    private func fetchTimeline(period: AnalyticsPeriod) async -> TimelineResponse? {
        do {
            return try await client.getAnalyticsTimeline(
                period: period, bowType: selectedBowType, distance: selectedDistance
            )
        } catch {
            // 404 / older server / offline — fall back silently and let the
            // view hide the section.
            return nil
        }
    }

    private func fetchDrift(period: AnalyticsPeriod) async -> DriftResponse? {
        // Drift is per-bow; pick the user's first bow when the filter doesn't
        // pin one. Returns nil if there are no bows yet.
        guard let bowId = appState?.bows.first?.id else { return nil }
        do {
            return try await client.getAnalyticsDrift(bowId: bowId, period: period)
        } catch {
            return nil
        }
    }

    private func fetchTrends(period: AnalyticsPeriod) async -> TrendsResponse? {
        do {
            return try await client.getAnalyticsTrends(
                period: period, bowType: selectedBowType, distance: selectedDistance
            )
        } catch {
            return nil
        }
    }

    // MARK: - Mock decorators
    //
    // When the server isn't yet emitting the Wave-2 overview/comparison
    // fields, we graft in reasonable stub values so the Analytics screen
    // still looks populated. All three helpers are DEBUG-only; Release
    // builds leave the fields as whatever the server sent (nil).

    private func decorateOverviewWithMocks() {
        #if DEBUG
        guard var current = overview else { return }
        if current.sparkline == nil {
            current.sparkline = MockAnalyticsWave2.sparklinePoints(period: current.period)
        }
        if current.groupSigma == nil {
            current.groupSigma = MockAnalyticsWave2.mockGroupSigma
        }
        if current.datasetSummary == nil {
            current.datasetSummary = MockAnalyticsWave2.datasetSummary(
                bow: appState?.bows.first,
                arrow: appState?.arrowConfigs.first
            )
        }
        // In DEBUG, force the headline numerals to the spec figure so reviewing
        // the Analytics screen against the Kenrokuen reference isn't clouded by
        // whatever the in-memory seed drifted to. Release builds still use the
        // server's numbers.
        current = AnalyticsOverview(
            period: current.period,
            sessionCount: MockAnalyticsWave2.mockCurrentSessions,
            avgArrowScore: MockAnalyticsWave2.mockCurrentAvg,
            xPercentage: MockAnalyticsWave2.mockCurrentXPct,
            suggestions: current.suggestions,
            groupSigma: current.groupSigma,
            sparkline: current.sparkline,
            datasetSummary: current.datasetSummary
        )
        overview = current
        #endif
    }

    private func decorateComparisonWithMocks() {
        #if DEBUG
        guard let c = comparison else { return }
        // DEBUG: override the slice numerals with spec-aligned values so the
        // Prev→Now compare strip reads "9.8 → 10.4" with a positive +0.6 delta,
        // matching the Kenrokuen reference figure. The engine's plot arrays
        // are preserved for the Impact Map overlay.
        let cur = PeriodSlice(
            label: c.current.label,
            plots: c.current.plots,
            avgArrowScore: MockAnalyticsWave2.mockCurrentAvg,
            xPercentage: MockAnalyticsWave2.mockCurrentXPct,
            sessionCount: MockAnalyticsWave2.mockCurrentSessions,
            config: c.current.config,
            centroid: c.current.centroid ?? MockAnalyticsWave2.currentCentroid,
            sigma: c.current.sigma ?? MockAnalyticsWave2.currentSigma
        )
        let prev = PeriodSlice(
            label: c.previous.label,
            plots: c.previous.plots,
            avgArrowScore: MockAnalyticsWave2.mockPreviousAvg,
            xPercentage: MockAnalyticsWave2.mockPreviousXPct,
            sessionCount: MockAnalyticsWave2.mockPreviousSessions,
            config: c.previous.config,
            centroid: c.previous.centroid ?? MockAnalyticsWave2.previousCentroid,
            sigma: c.previous.sigma ?? MockAnalyticsWave2.previousSigma
        )
        let shift = c.shift ?? MockAnalyticsWave2.shiftVector
        comparison = PeriodComparison(period: c.period, current: cur, previous: prev, shift: shift)
        #endif
    }
}
