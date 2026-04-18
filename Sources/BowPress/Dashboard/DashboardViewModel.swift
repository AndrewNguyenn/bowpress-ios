import Foundation
import Observation

@Observable
final class DashboardViewModel {
    var suggestions: [AnalyticsSuggestion] = []
    var isLoading: Bool = false
    var error: String?

    // MARK: - Computed

    /// Groups suggestions by bowId. Within each group, unread suggestions come first,
    /// then read. Both sub-groups are sorted newest-first.
    var groupedSuggestions: [(bowId: String, suggestions: [AnalyticsSuggestion])] {
        let byBow = Dictionary(grouping: suggestions, by: \.bowId)
        return byBow
            .map { bowId, items in
                let sorted = items.sorted {
                    // unread before read
                    if $0.wasRead != $1.wasRead { return !$0.wasRead }
                    return $0.createdAt > $1.createdAt
                }
                return (bowId: bowId, suggestions: sorted)
            }
            // stable ordering: bows with more unread first, then alphabetically by id
            .sorted {
                let lhsUnread = $0.suggestions.filter { !$0.wasRead }.count
                let rhsUnread = $1.suggestions.filter { !$0.wasRead }.count
                if lhsUnread != rhsUnread { return lhsUnread > rhsUnread }
                return $0.bowId < $1.bowId
            }
    }

    // MARK: - Actions

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        do {
            let fetched = try await APIClient.shared.fetchSuggestions()
            let readIds = Set(suggestions.filter(\.wasRead).map(\.id))
            suggestions = fetched.map { s in
                var copy = s
                if readIds.contains(s.id) { copy.wasRead = true }
                return copy
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Marks a suggestion as read locally (immediate UI update) and syncs with the API.
    func markRead(_ suggestion: AnalyticsSuggestion) async {
        guard !suggestion.wasRead else { return }
        // Optimistic local update
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
