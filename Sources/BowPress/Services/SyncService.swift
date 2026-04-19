import Foundation

/// Fire-and-forget background sync to the API.
/// Each method persists to the backend after the local store has already committed.
/// Errors are swallowed — local store is the source of truth.
final class SyncService {
    private let api: BowPressAPIClient

    init(api: BowPressAPIClient = APIClient.shared) {
        self.api = api
    }

    func syncBow(_ bow: Bow) {
        Task { try? await api.createBow(bow) }
    }

    func syncConfig(_ config: BowConfiguration) {
        Task { try? await api.createConfiguration(config) }
    }

    func syncArrowConfig(_ config: ArrowConfiguration) {
        Task { try? await api.createArrowConfig(config) }
    }

    func syncSession(_ session: ShootingSession) {
        Task { try? await api.createSession(session) }
    }

    func syncArrow(_ arrow: ArrowPlot) {
        Task { try? await api.plotArrow(arrow) }
    }

    func syncEnd(_ end: SessionEnd) {
        Task { try? await api.completeEnd(end) }
    }

    func syncEndSession(id: String, notes: String) {
        Task { try? await api.endSession(id: id, notes: notes) }
    }
}
