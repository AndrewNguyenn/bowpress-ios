import Foundation

/// First-launch hydration of LocalStore from the API. Called by MainTabView
/// on app start, after the user is authenticated. Each entity is only pulled
/// when its corresponding LocalStore bucket is empty — subsequent launches
/// reuse the on-disk cache (and thus work offline).
///
/// All network failures are swallowed intentionally (try?); a failed pull
/// leaves the store empty rather than crashing, and the next relaunch will
/// try again. This mirrors the existing local-first model where LocalStore
/// is the source of truth and the API is best-effort.
enum LocalHydration {

    @MainActor
    static func hydrateFromAPI(store: LocalStore, api: BowPressAPIClient) async {
        if (try? store.fetchBows())?.isEmpty == true {
            if let bows = try? await api.fetchBows() {
                for bow in bows { try? store.save(bow: bow) }
                for bow in bows {
                    if let configs = try? await api.fetchConfigurations(bowId: bow.id) {
                        for config in configs { try? store.save(config: config) }
                    }
                }
            }
        }
        if (try? store.fetchArrowConfigs())?.isEmpty == true {
            if let arrows = try? await api.fetchArrowConfigs() {
                for arrow in arrows { try? store.save(arrowConfig: arrow) }
            }
        }
        if (try? store.fetchSessions())?.isEmpty == true {
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
}
