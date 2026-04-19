import Foundation
import Observation

@Observable @MainActor final class SessionViewModel {

    // MARK: - Dependencies

    private let apiClient: BowPressAPIClient
    var store: LocalStore?

    /// Called whenever the active bow config is confirmed (session start or first shot after a change).
    /// Wire this up in the host view to propagate the confirmed config to AppState.
    var onConfigConfirmed: ((String, BowConfiguration) -> Void)?

    /// Called when a session is successfully ended. Passes the completed session for immediate local display.
    var onSessionCompleted: ((ShootingSession) -> Void)?

    init(apiClient: BowPressAPIClient = APIClient.shared, store: LocalStore? = nil) {
        self.apiClient = apiClient
        self.store = store
    }

    // MARK: - Active Session State

    var currentSession: ShootingSession?
    var isSessionActive: Bool = false

    // MARK: - Confirmed Configs

    /// The configs that the current (or most recent) session segment was created with.
    var activeBowConfig: BowConfiguration?
    var activeArrowConfig: ArrowConfiguration?

    // MARK: - Pending Config Change

    /// Set when the archer changes a config mid-session.
    /// Cleared and promoted to active the moment the first arrow after the change is plotted.
    var pendingBowConfig: BowConfiguration?
    var pendingArrowConfig: ArrowConfiguration?

    var hasPendingConfigChange: Bool {
        pendingBowConfig != nil || pendingArrowConfig != nil
    }

    // MARK: - Arrows

    /// Arrows plotted in the current logical segment (under the current active config).
    var currentArrows: [ArrowPlot] = []

    /// All arrows across every segment this session (for display purposes).
    var allArrows: [ArrowPlot] = []

    // MARK: - Ends

    var completedEnds: [SessionEnd] = []
    /// Parallel to completedEnds — how many arrows were in each end.
    var endArrowCounts: [Int] = []

    var currentEndNumber: Int { completedEnds.count + 1 }

    var currentEndArrows: [ArrowPlot] {
        let completedCount = endArrowCounts.reduce(0, +)
        return Array(allArrows.dropFirst(completedCount))
    }

    // MARK: - Notes

    /// Persists for the whole session. Never cleared automatically.
    var sessionNotes: String = ""

    // MARK: - Setup

    var selectedBow: Bow?

    /// All known configs for the current bow — used to match pending changes against history.
    var knownBowConfigs: [BowConfiguration] = []

    // MARK: - UI State

    var isLoading: Bool = false
    var error: String?

    // MARK: - Public API

    /// Start a brand-new session. Creates the ShootingSession in the DB immediately —
    /// subsequent segments inside the same shooting block use lazy creation.
    func startSession(
        bow: Bow,
        bowConfig: BowConfiguration,
        arrowConfig: ArrowConfiguration,
        knownConfigs: [BowConfiguration] = []
    ) async {
        isLoading = true
        error = nil
        let session = ShootingSession(
            id: UUID().uuidString,
            bowId: bow.id,
            bowConfigId: bowConfig.id,
            arrowConfigId: arrowConfig.id,
            startedAt: Date(),
            endedAt: nil,
            notes: "",
            feelTags: [],
            arrowCount: 0
        )
        // Persist locally first — session exists even if server is unreachable
        try? store?.save(session: session)
        currentSession = session
        activeBowConfig = bowConfig
        activeArrowConfig = arrowConfig
        selectedBow = bow
        knownBowConfigs = knownConfigs.isEmpty ? [bowConfig] : knownConfigs
        onConfigConfirmed?(bow.id, bowConfig)
        currentArrows = []
        allArrows = []
        completedEnds = []
        endArrowCounts = []
        sessionNotes = ""
        pendingBowConfig = nil
        pendingArrowConfig = nil
        isSessionActive = true
        // Best-effort immediate sync; BackgroundSyncService retries if offline
        Task {
            if let _ = try? await apiClient.createSession(session) {
                try? store?.markSessionSynced(id: session.id)
            }
        }
        isLoading = false
    }

    /// Apply a mid-session config change.
    /// Stores the new values as pending and clears arrowNotes.
    /// Does NOT write to the DB yet.
    func applyConfigChange(
        bowConfig: BowConfiguration?,
        arrowConfig: ArrowConfiguration?
    ) {
        if let bowConfig {
            pendingBowConfig = bowConfig
        }
        if let arrowConfig {
            pendingArrowConfig = arrowConfig
        }
    }

    /// Plot an arrow. Handles lazy session creation when a config change is pending.
    func plotArrow(ring: Int, zone: ArrowPlot.Zone, plotX: Double, plotY: Double) async {
        guard isSessionActive else { return }

        isLoading = true
        error = nil
        // Lazy session creation: if there is a pending config change we must open
        // a new session segment before recording the arrow.
        if hasPendingConfigChange {
            let pendingBow = pendingBowConfig ?? activeBowConfig!
            let resolvedArrowConfig = pendingArrowConfig ?? activeArrowConfig!
            let bow = selectedBow!

            // Match pending config values against history before creating a new record.
            let resolvedBowConfig: BowConfiguration
            if let historical = knownBowConfigs.first(where: { $0.hasMatchingValues(pendingBow) }) {
                // Values match an existing config — reuse it, no API call needed.
                resolvedBowConfig = historical
            } else {
                // Genuinely new config — persist it now that a shot is being fired.
                try? store?.save(config: pendingBow)
                knownBowConfigs.append(pendingBow)
                resolvedBowConfig = pendingBow
                Task {
                    if let _ = try? await apiClient.createConfiguration(pendingBow) {
                        try? store?.markBowConfigSynced(id: pendingBow.id)
                    }
                }
            }

            let newSession = ShootingSession(
                id: UUID().uuidString,
                bowId: bow.id,
                bowConfigId: resolvedBowConfig.id,
                arrowConfigId: resolvedArrowConfig.id,
                startedAt: Date(),
                endedAt: nil,
                notes: "",
                feelTags: [],
                arrowCount: 0
            )
            try? store?.save(session: newSession)
            currentSession = newSession
            Task {
                if let _ = try? await apiClient.createSession(newSession) {
                    try? store?.markSessionSynced(id: newSession.id)
                }
            }

            // Promote pending → active
            activeBowConfig = resolvedBowConfig
            activeArrowConfig = resolvedArrowConfig
            pendingBowConfig = nil
            pendingArrowConfig = nil
            currentArrows = []
            onConfigConfirmed?(bow.id, resolvedBowConfig)

        } else if currentSession == nil {
            let bow = selectedBow!
            let bowConfig = activeBowConfig!
            let arrowConfig = activeArrowConfig!

            let firstSession = ShootingSession(
                id: UUID().uuidString,
                bowId: bow.id,
                bowConfigId: bowConfig.id,
                arrowConfigId: arrowConfig.id,
                startedAt: Date(),
                endedAt: nil,
                notes: "",
                feelTags: [],
                arrowCount: 0
            )
            try? store?.save(session: firstSession)
            currentSession = firstSession
            Task {
                if let _ = try? await apiClient.createSession(firstSession) {
                    try? store?.markSessionSynced(id: firstSession.id)
                }
            }
        }

        // Build and record the arrow plot
        let plot = ArrowPlot(
            id: UUID().uuidString,
            sessionId: currentSession!.id,
            bowConfigId: activeBowConfig!.id,
            arrowConfigId: activeArrowConfig!.id,
            ring: ring,
            zone: zone,
            plotX: plotX,
            plotY: plotY,
            shotAt: Date(),
            excluded: false,
            notes: nil
        )
        // Save locally first — arrow is never lost even if offline
        try? store?.save(arrow: plot)
        currentArrows.append(plot)
        allArrows.append(plot)
        Task {
            if let _ = try? await apiClient.plotArrow(plot) {
                try? store?.markPlotSynced(id: plot.id)
            }
        }

        isLoading = false
    }

    /// Toggle an arrow's flier (excluded) flag. Updates local state + store immediately,
    /// fires background API sync. Spec §ArrowPlot.excluded — archer-controlled flier flag.
    func toggleFlier(arrowId: String) {
        guard let idx = allArrows.firstIndex(where: { $0.id == arrowId }) else { return }
        allArrows[idx].excluded.toggle()
        let updated = allArrows[idx]
        try? store?.save(arrow: updated)
        if let currentIdx = currentArrows.firstIndex(where: { $0.id == arrowId }) {
            currentArrows[currentIdx].excluded = updated.excluded
        }
        // Background API sync — best-effort, BackgroundSyncService retries on failure.
        Task { try? await apiClient.plotArrow(updated) }
    }

    /// End the current session. Saves locally immediately for instant analytics visibility,
    /// fires onSessionCompleted, and kicks the backend so the analytics pipeline runs
    /// right away (the backend enqueues the Cloudflare Workflow when `endedAt` transitions
    /// from null → set on PUT /sessions/:id). Falls back silently on network error —
    /// BackgroundSyncService will catch it on the next connectivity event.
    func endSession() async {
        guard let session = currentSession else { resetState(); return }
        isLoading = true
        error = nil
        let endedAt = Date()
        let notes = sessionNotes
        try? store?.updateSession(id: session.id, endedAt: endedAt, notes: notes, arrowCount: allArrows.count)
        let completed = ShootingSession(
            id: session.id,
            bowId: session.bowId,
            bowConfigId: session.bowConfigId,
            arrowConfigId: session.arrowConfigId,
            startedAt: session.startedAt,
            endedAt: endedAt,
            notes: notes,
            feelTags: session.feelTags,
            arrowCount: allArrows.count
        )
        onSessionCompleted?(completed)
        // Trigger analytics pipeline immediately — spec: "Every time a session closes".
        // Awaited so by the time this function returns, the session is either synced
        // (marked so BackgroundSyncService doesn't double-fire) or still pending (drain
        // retries on next connectivity event).
        do {
            try await apiClient.endSession(id: session.id, notes: notes)
            try? store?.markSessionSynced(id: session.id)
        } catch {
            // Best-effort — leave pendingSync set so drain retries on reconnect.
        }
        resetState()
    }

    /// Discard the session — deletes it from the backend so it won't appear in analytics.
    func cancelSession() async {
        guard let session = currentSession else { resetState(); return }
        isLoading = true
        do {
            try await apiClient.deleteSession(id: session.id)
        } catch {
            // Proceed with local reset even if the delete fails
        }
        resetState()
    }

    private func resetState() {
        currentSession = nil
        isSessionActive = false
        activeBowConfig = nil
        activeArrowConfig = nil
        pendingBowConfig = nil
        pendingArrowConfig = nil
        currentArrows = []
        allArrows = []
        completedEnds = []
        endArrowCounts = []
        sessionNotes = ""
        selectedBow = nil
        isLoading = false
    }

    /// Complete the current end, saving it with optional notes.
    func completeEnd(notes: String?) async {
        guard isSessionActive, !currentEndArrows.isEmpty, let session = currentSession else { return }
        isLoading = true
        error = nil
        do {
            let arrowsInEnd = currentEndArrows
            let count = arrowsInEnd.count
            let newEnd = SessionEnd(
                id: UUID().uuidString,
                sessionId: session.id,
                endNumber: currentEndNumber,
                notes: notes?.isEmpty == true ? nil : notes,
                completedAt: Date()
            )
            let saved = try await apiClient.completeEnd(newEnd)
            completedEnds.append(saved)
            endArrowCounts.append(count)
            try? store?.save(end: saved)
            // Stamp each arrow that belonged to this end with the new end's id.
            // Mirrors the plotArrow/toggleFlier pattern: update in-memory, persist locally,
            // fire best-effort API sync, mark synced on success.
            for arrow in arrowsInEnd {
                var updated = arrow
                updated.endId = saved.id
                if let idx = allArrows.firstIndex(where: { $0.id == updated.id }) {
                    allArrows[idx].endId = saved.id
                }
                try? store?.save(arrow: updated)
                Task {
                    if let _ = try? await apiClient.plotArrow(updated) {
                        try? store?.markPlotSynced(id: updated.id)
                    }
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Undo — removes the last plotted arrow from local state only.
    /// Cannot undo past a completed end.
    func removeLastArrow() {
        let completedCount = endArrowCounts.reduce(0, +)
        guard allArrows.count > completedCount else { return }
        let removed = allArrows.removeLast()
        currentArrows.removeAll { $0.id == removed.id }
    }
}
