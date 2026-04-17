import Foundation
import Observation

@Observable final class SessionViewModel {

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
        do {
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
            let created = try await APIClient.shared.createSession(session)
            currentSession = created
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
        } catch {
            self.error = error.localizedDescription
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
        do {
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
                let created = try await APIClient.shared.createSession(newSession)
                currentSession = created

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
                let created = try await APIClient.shared.createSession(firstSession)
                currentSession = created
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
            let saved = try await APIClient.shared.plotArrow(plot)
            currentArrows.append(saved)
            allArrows.append(saved)

        } catch {
            self.error = error.localizedDescription
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
        do {
            try await APIClient.shared.endSession(id: session.id, notes: sessionNotes)
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
        do {
            let count = currentEndArrows.count
            let newEnd = SessionEnd(
                id: UUID().uuidString,
                sessionId: session.id,
                endNumber: currentEndNumber,
                notes: notes?.isEmpty == true ? nil : notes,
                completedAt: Date()
            )
            let saved = try await APIClient.shared.completeEnd(newEnd)
            completedEnds.append(saved)
            endArrowCounts.append(count)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Undo — removes the last plotted arrow from local state only.
    func removeLastArrow() {
        guard !allArrows.isEmpty else { return }
        let removed = allArrows.removeLast()
        currentArrows.removeAll { $0.id == removed.id }
    }
}
