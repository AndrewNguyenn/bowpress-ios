import Foundation
import Observation

@Observable @MainActor
final class AnalyticsViewModel {
    var selectedPeriod: AnalyticsPeriod = .threeDays
    var overview: AnalyticsOverview?
    var comparison: PeriodComparison?
    var suggestions: [AnalyticsSuggestion] = []
    var extraInsights: [TrendInsight] = []
    var isLoading: Bool = false
    var error: String?

    private var engine: LocalAnalyticsEngine?
    private var appState: AppState?

    func configure(store: LocalStore) {
        engine = LocalAnalyticsEngine(store: store)
    }

    func configure(store: LocalStore, appState: AppState) {
        engine = LocalAnalyticsEngine(store: store)
        self.appState = appState
    }

    // MARK: - Public API

    func load(period: AnalyticsPeriod) async {
        guard !isLoading, let engine else { return }
        selectedPeriod = period
        isLoading = true
        error = nil
        do {
            overview = try engine.overview(period: period)
            comparison = try engine.comparison(period: period)
            extraInsights = (try? engine.multiSessionInsights()) ?? []
            let readIds = Set(suggestions.filter(\.wasRead).map(\.id))
            var all: [AnalyticsSuggestion] = []
            if let appState {
                for bow in appState.bows {
                    let list = (try? await APIClient.shared.fetchSuggestions(bowId: bow.id)) ?? []
                    all.append(contentsOf: list)
                }
            } else {
                all = (try? await APIClient.shared.fetchSuggestions()) ?? []
            }
            suggestions = all.map { s in
                var copy = s
                if readIds.contains(s.id) { copy.wasRead = true }
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
}
