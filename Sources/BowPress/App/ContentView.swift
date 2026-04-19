import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

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
                if appState.isHydrating {
                    HydrationSplashView()
                        .transition(.opacity)
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
