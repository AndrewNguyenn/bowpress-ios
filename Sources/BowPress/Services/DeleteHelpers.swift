import Foundation

/// Shared delete helpers that coordinate the optimistic-remove + local-store + async-API
/// dance so all three entry points (list swipe, bow detail, arrow detail) stay in sync.
///
/// Pattern per call:
///   1. Optimistically remove from `appState` so the UI updates immediately
///   2. Commit to the local SwiftData store (synchronous); rollback `appState` on failure
///   3. Fire-and-forget the backend delete — local is the source of truth, backend cascades
///
/// Returns an `Error` if the local delete failed (caller surfaces via its `errorMessage`
/// alert); `nil` on success.

@MainActor
func deleteBowEverywhere(_ bow: Bow, appState: AppState, store: LocalStore) -> Error? {
    let removed = appState.bows.first { $0.id == bow.id }
    appState.bows.removeAll { $0.id == bow.id }
    do {
        try store.deleteBow(id: bow.id)
    } catch {
        if let removed { appState.bows.append(removed) }
        return error
    }
    Task { try? await APIClient.shared.deleteBow(id: bow.id) }
    return nil
}

@MainActor
func deleteArrowEverywhere(_ arrow: ArrowConfiguration, appState: AppState, store: LocalStore) -> Error? {
    let removed = appState.arrowConfigs.first { $0.id == arrow.id }
    appState.arrowConfigs.removeAll { $0.id == arrow.id }
    do {
        try store.deleteArrowConfig(id: arrow.id)
    } catch {
        if let removed { appState.arrowConfigs.append(removed) }
        return error
    }
    Task { try? await APIClient.shared.deleteArrowConfig(id: arrow.id) }
    return nil
}

@MainActor
func deleteSessionEverywhere(_ session: ShootingSession, appState: AppState, store: LocalStore) -> Error? {
    let removed = appState.completedSessions.first { $0.id == session.id }
    appState.completedSessions.removeAll { $0.id == session.id }
    do {
        try store.deleteSession(id: session.id)
    } catch {
        if let removed { appState.completedSessions.append(removed) }
        return error
    }
    Task { try? await APIClient.shared.deleteSession(id: session.id) }
    return nil
}
