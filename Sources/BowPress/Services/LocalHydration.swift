import Foundation

/// Hydrates LocalStore from the API on every launch. Called by MainTabView
/// on app start, after the user is authenticated. Every entity is always
/// pulled; LocalStore.save is an upsert, so re-running is idempotent (and
/// in DEBUG, where SwiftData is in-memory, this guarantees fresh fixtures
/// every launch).
///
/// All network failures are swallowed intentionally (try?); a failed pull
/// leaves the store as-is rather than crashing, and the next relaunch will
/// try again. This mirrors the existing local-first model where LocalStore
/// is the source of truth and the API is best-effort.
enum LocalHydration {

    @MainActor
    static func hydrateFromAPI(store: LocalStore, api: BowPressAPIClient) async {
        if let bows = try? await api.fetchBows() {
            for bow in bows { try? store.save(bow: bow) }
            for bow in bows {
                if let configs = try? await api.fetchConfigurations(bowId: bow.id) {
                    for config in configs { try? store.save(config: config) }
                }
            }
        }
        if let arrows = try? await api.fetchArrowConfigs() {
            for arrow in arrows { try? store.save(arrowConfig: arrow) }
        }
        if let sessions = try? await api.fetchSessions() {
            for session in sessions {
                try? store.save(session: session)
                if let plots = try? await api.fetchPlots(sessionId: session.id) {
                    for plot in plots { try? store.save(arrow: plot) }
                }
            }
        }
    }
}
