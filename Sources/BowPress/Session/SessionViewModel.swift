import Foundation
import Observation

@Observable @MainActor final class SessionViewModel {

    // MARK: - Dependencies

    /// Local store for offline-first session persistence. Optional so call sites that
    /// construct `SessionViewModel()` (previews, legacy tests) keep compiling; the host
    /// view assigns it in its `.task` block.
    var store: LocalStore?

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

    // MARK: - UI State

    var isLoading: Bool = false
    var error: String?

    // MARK: - Public API

    /// Start a brand-new session. Creates the ShootingSession in the DB immediately —
    /// subsequent segments inside the same shooting block use lazy creation.
    func startSession(
        bow: Bow,
        bowConfig: BowConfiguration,
        arrowConfig: ArrowConfiguration
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
            conditions: nil,
            arrowCount: 0
        )
        try? store?.save(session: session)
        currentSession = session
        activeBowConfig = bowConfig
        activeArrowConfig = arrowConfig
        selectedBow = bow
        currentArrows = []
        allArrows = []
        completedEnds = []
        endArrowCounts = []
        sessionNotes = ""
        pendingBowConfig = nil
        pendingArrowConfig = nil
        isSessionActive = true
        let store = self.store
        Task {
            if let _ = try? await APIClient.shared.createSession(session) {
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
        let store = self.store

        // Lazy session creation: if there is a pending config change we must open
        // a new session segment before recording the arrow.
        if hasPendingConfigChange {
            let resolvedBowConfig = pendingBowConfig ?? activeBowConfig!
            let resolvedArrowConfig = pendingArrowConfig ?? activeArrowConfig!
            let bow = selectedBow!

            let newSession = ShootingSession(
                id: UUID().uuidString,
                bowId: bow.id,
                bowConfigId: resolvedBowConfig.id,
                arrowConfigId: resolvedArrowConfig.id,
                startedAt: Date(),
                endedAt: nil,
                notes: "",
                feelTags: [],
                conditions: nil,
                arrowCount: 0
            )
            try? store?.save(session: newSession)
            currentSession = newSession
            Task {
                if let _ = try? await APIClient.shared.createSession(newSession) {
                    try? store?.markSessionSynced(id: newSession.id)
                }
            }

            // Promote pending → active
            activeBowConfig = resolvedBowConfig
            activeArrowConfig = resolvedArrowConfig
            pendingBowConfig = nil
            pendingArrowConfig = nil
            currentArrows = []

        } else if currentSession == nil {
            // Safety net: should not normally be reached after startSession(),
            // but guard against it anyway.
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
                conditions: nil,
                arrowCount: 0
            )
            try? store?.save(session: firstSession)
            currentSession = firstSession
            Task {
                if let _ = try? await APIClient.shared.createSession(firstSession) {
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
        try? store?.save(arrow: plot)
        currentArrows.append(plot)
        allArrows.append(plot)
        Task {
            if let _ = try? await APIClient.shared.plotArrow(plot) {
                try? store?.markPlotSynced(id: plot.id)
            }
        }

        isLoading = false
    }

    /// End the current session, flushing the latest session notes to the API.
    func endSession() async {
        guard let session = currentSession else {
            isSessionActive = false
            return
        }
        isLoading = true
        error = nil
        let endedAt = Date()
        let notes = sessionNotes
        // Persist the true arrow count locally so the session log row renders correctly
        // even if the session already exists as a row with arrowCount=0 from startSession.
        try? store?.updateSession(
            id: session.id,
            endedAt: endedAt,
            notes: notes,
            arrowCount: allArrows.count
        )
        do {
            try await APIClient.shared.endSession(id: session.id, notes: notes)
            try? store?.markSessionSynced(id: session.id)
        } catch {
            self.error = error.localizedDescription
        }
        // Reset regardless of error so the UI returns to setup
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
        let store = self.store
        let arrowsInEnd = currentEndArrows
        let count = arrowsInEnd.count
        let newEnd = SessionEnd(
            id: UUID().uuidString,
            sessionId: session.id,
            endNumber: currentEndNumber,
            notes: notes?.isEmpty == true ? nil : notes,
            completedAt: Date()
        )
        try? store?.save(end: newEnd)
        // Stamp each arrow that belonged to this end with the new end's id.
        // Without this, the session detail's per-end filter returns empty.
        for arrow in arrowsInEnd {
            var updated = arrow
            updated.endId = newEnd.id
            if let idx = allArrows.firstIndex(where: { $0.id == updated.id }) {
                allArrows[idx].endId = newEnd.id
            }
            if let idx = currentArrows.firstIndex(where: { $0.id == updated.id }) {
                currentArrows[idx].endId = newEnd.id
            }
            try? store?.save(arrow: updated)
            Task { [updated] in
                if let _ = try? await APIClient.shared.plotArrow(updated) {
                    try? store?.markPlotSynced(id: updated.id)
                }
            }
        }
        completedEnds.append(newEnd)
        endArrowCounts.append(count)
        Task { [newEnd] in
            _ = try? await APIClient.shared.completeEnd(newEnd)
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
