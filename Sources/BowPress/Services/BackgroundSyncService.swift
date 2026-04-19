import Foundation
import Network

/// Drains all pendingSync entities to the server in dependency order.
/// Triggered on connectivity restore and on app launch.
/// All data is already in SwiftData — this service is the retry mechanism.
@MainActor
final class BackgroundSyncService {
    private let api: BowPressAPIClient
    private var store: LocalStore?
    private var isSyncing = false
    nonisolated(unsafe) private let monitor = NWPathMonitor()

    init(api: BowPressAPIClient = APIClient.shared) {
        self.api = api
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor [weak self] in self?.triggerSync() }
        }
    }

    deinit {
        monitor.cancel()
    }

    func configure(store: LocalStore) {
        self.store = store
        monitor.start(queue: DispatchQueue(label: "bowpress.sync", qos: .background))
    }

    func triggerSync() {
        guard !isSyncing, store != nil else { return }
        Task { await drain() }
    }

    // MARK: - Drain

    func drain() async {
        guard let store else { return }
        isSyncing = true
        defer { isSyncing = false }

        // Dependency order: bows → bow-configs → arrow-configs → sessions → plots
        await syncBows(store: store)
        await syncBowConfigs(store: store)
        await syncArrowConfigs(store: store)
        await syncSessions(store: store)
        await syncPlots(store: store)
    }

    private func syncBows(store: LocalStore) async {
        guard let pending = try? store.fetchPendingBows() else { return }
        for bow in pending {
            do {
                _ = try await api.createBow(bow)
                try? store.markBowSynced(id: bow.id)
            } catch { /* will retry on next connectivity event */ }
        }
    }

    private func syncBowConfigs(store: LocalStore) async {
        guard let pending = try? store.fetchPendingBowConfigs() else { return }
        for config in pending {
            do {
                _ = try await api.createConfiguration(config)
                try? store.markBowConfigSynced(id: config.id)
            } catch {}
        }
    }

    private func syncArrowConfigs(store: LocalStore) async {
        guard let pending = try? store.fetchPendingArrowConfigs() else { return }
        for config in pending {
            do {
                _ = try await api.createArrowConfig(config)
                try? store.markArrowConfigSynced(id: config.id)
            } catch {}
        }
    }

    private func syncSessions(store: LocalStore) async {
        guard let pending = try? store.fetchPendingSessions() else { return }
        for session in pending {
            do {
                _ = try await api.createSession(session)
                // If the session is already ended, also sync the end state
                if session.endedAt != nil {
                    try await api.endSession(id: session.id, notes: session.notes)
                }
                try? store.markSessionSynced(id: session.id)
            } catch {}
        }
    }

    private func syncPlots(store: LocalStore) async {
        guard let pending = try? store.fetchPendingPlots() else { return }
        for plot in pending {
            do {
                _ = try await api.plotArrow(plot)
                try? store.markPlotSynced(id: plot.id)
            } catch {}
        }
    }
}
