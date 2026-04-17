import Foundation
import Observation

@Observable
final class AnalyticsViewModel {
    var selectedBowId: String?
    var selectedPeriod: AnalyticsPeriod = .week
    var overview: AnalyticsOverview?
    var comparison: PeriodComparison?
    var suggestions: [AnalyticsSuggestion] = []
    var isLoading: Bool = false
    var error: String?

    // MARK: - Public API

    /// Fetches the overview, comparison, and suggestions for the given bow/period, then caches
    /// the selection so `refresh()` can re-issue the same request.
    func load(bowId: String, period: AnalyticsPeriod) async {
        guard !isLoading else { return }
        selectedBowId = bowId
        selectedPeriod = period
        isLoading = true
        error = nil
        do {
            async let overviewFetch = APIClient.shared.fetchAnalyticsOverview(bowId: bowId, period: period)
            async let suggestionsFetch = APIClient.shared.fetchSuggestions(bowId: bowId)
            async let comparisonFetch = APIClient.shared.fetchComparison(bowId: bowId, period: period)
            let (fetchedOverview, fetchedSuggestions, fetchedComparison) = try await (overviewFetch, suggestionsFetch, comparisonFetch)
            overview = fetchedOverview
            comparison = fetchedComparison
            // Preserve any locally-applied read-state mutations.
            let readIds = Set(suggestions.filter(\.wasRead).map(\.id))
            suggestions = fetchedSuggestions.map { s in
                var copy = s
                if readIds.contains(s.id) { copy.wasRead = true }
                return copy
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Re-fetches with the current `selectedBowId` and `selectedPeriod`.
    /// No-ops if no bow has ever been selected.
    func refresh() async {
        guard let bowId = selectedBowId else { return }
        await load(bowId: bowId, period: selectedPeriod)
    }

    /// Marks a suggestion as read locally and syncs with the API.
    func markRead(_ suggestion: AnalyticsSuggestion) async {
        guard !suggestion.wasRead else { return }
        if let idx = suggestions.firstIndex(where: { $0.id == suggestion.id }) {
            suggestions[idx].wasRead = true
        }
        do {
            try await APIClient.shared.markSuggestionRead(id: suggestion.id)
        } catch {
            // Revert on failure
            if let idx = suggestions.firstIndex(where: { $0.id == suggestion.id }) {
                suggestions[idx].wasRead = false
            }
        }
    }
}
