import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    /// Tracks whether the splash has played long enough to "land". Combined
    /// with `appState.isHydrating` so a fast hydrate doesn't truncate the
    /// 2.6s motion gate inside `HydrationSplashView`.
    @State private var splashSettled = false

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
                if appState.isHydrating || !splashSettled {
                    HydrationSplashView(onMinimumElapsed: {
                        withAnimation(.easeOut(duration: 0.45)) {
                            splashSettled = true
                        }
                    })
                    .transition(.opacity.animation(.easeOut(duration: 0.45)))
                    .zIndex(1)
                }
            }
        }
    }
}

#Preview {
    let state = AppState()
    ContentView().environment(state)
}
