import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    /// Tracks whether the splash has played long enough to "land" — flipped
    /// from `HydrationSplashView.onMinimumElapsed` after the 2.6s motion gate.
    @State private var splashSettled = false

    /// Single source of truth for "the splash is gone." Once true, the view
    /// is removed from the hierarchy entirely — no `.transition(.opacity)`
    /// ghost, no partial-alpha residual behind sparse tabs (Log / Equipment /
    /// Settings). Flipped in one of three places:
    ///   1. the natural path: motion gate + hydration both resolved,
    ///   2. the safety timeout: hydration never flips (API unreachable —
    ///      `LocalHydration.hydrateFromAPI` against `localhost:8787` hangs
    ///      when there's no backend),
    ///   3. a task cancel on re-mount (handled by @State lifetime).
    @State private var splashDismissed = false

    /// Hard ceiling from first render. Keeps a hang-on-no-backend from
    /// stranding the splash indefinitely — worst case the user sees 4.5s
    /// of splash, then we force dismissal regardless of `isHydrating`.
    private let splashSafetyTimeout: Duration = .seconds(4.5)

    var body: some View {
        if !appState.isAuthenticated {
            AuthView()
        } else {
            ZStack {
                MainTabView()
                    .readOnlyGate(!appState.isSubscribed)
                    .task {
                        await SubscriptionManager.shared.refreshEntitlement()
                        appState.entitlement = SubscriptionManager.shared.entitlement
                    }
                if !splashDismissed {
                    HydrationSplashView(onMinimumElapsed: {
                        splashSettled = true
                        dismissSplashIfReady()
                    })
                    .transition(.opacity.animation(.easeInOut(duration: 0.45)))
                    .zIndex(1)
                    .task {
                        try? await Task.sleep(for: splashSafetyTimeout)
                        // If the natural condition hasn't fired by now,
                        // force dismissal — the app is usable even when
                        // hydration is spinning its wheels.
                        if !splashDismissed {
                            withAnimation(.easeInOut(duration: 0.45)) {
                                splashDismissed = true
                            }
                        }
                    }
                    .onChange(of: appState.isHydrating) { _, _ in
                        dismissSplashIfReady()
                    }
                }
            }
        }
    }

    /// Drops the splash once both the motion gate and hydration are done.
    /// No-op if the conditions haven't aligned — the timeout in `.task`
    /// catches the hung-hydration case.
    private func dismissSplashIfReady() {
        guard splashSettled, !appState.isHydrating, !splashDismissed else { return }
        withAnimation(.easeInOut(duration: 0.45)) {
            splashDismissed = true
        }
    }
}

#Preview {
    let state = AppState()
    ContentView().environment(state)
}
