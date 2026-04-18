import Foundation
import Observation

@Observable @MainActor
final class AnalyticsViewModel {
    var selectedPeriod: AnalyticsPeriod = .threeDays
    var overview: AnalyticsOverview?
    var comparison: PeriodComparison?
    var suggestions: [AnalyticsSuggestion] = []
    var isLoading: Bool = false
    var error: String?

    // MARK: - Public API

    func load(period: AnalyticsPeriod) async {
        guard !isLoading else { return }
        selectedPeriod = period
        isLoading = true
        error = nil
        do {
            async let overviewFetch = APIClient.shared.fetchAnalyticsOverview(period: period)
            async let suggestionsFetch = APIClient.shared.fetchSuggestions()
            async let comparisonFetch = APIClient.shared.fetchComparison(period: period)
            let (fetchedOverview, fetchedSuggestions, fetchedComparison) = try await (overviewFetch, suggestionsFetch, comparisonFetch)
            overview = fetchedOverview
            comparison = fetchedComparison
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

    func refresh() async {
        await load(period: selectedPeriod)
    }

    func markRead(_ suggestion: AnalyticsSuggestion) async {
        guard !suggestion.wasRead else { return }
        if let idx = suggestions.firstIndex(where: { $0.id == suggestion.id }) {
            suggestions[idx].wasRead = true
        }
        do {
            try await APIClient.shared.markSuggestionRead(id: suggestion.id)
        } catch {
            if let idx = suggestions.firstIndex(where: { $0.id == suggestion.id }) {
                suggestions[idx].wasRead = false
            }
        }
    }
}
