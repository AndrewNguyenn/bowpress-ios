import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        rootContent
    }

    @ViewBuilder
    private var rootContent: some View {
        if !appState.isAuthenticated {
            AuthView()
        } else if appState.isSubscribed {
            MainTabView()
        } else {
            PaywallView()
                .task {
                    // Pick up a fresher backend entitlement in case a restore
                    // happened on another device.
                    await SubscriptionManager.shared.refreshEntitlement()
                    appState.entitlement = SubscriptionManager.shared.entitlement
                }
        }
    }
}

#Preview {
    let state = AppState()
    ContentView()
        .environment(state)
}
