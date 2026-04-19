import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if !appState.isAuthenticated {
            AuthView()
        } else {
            MainTabView()
                .readOnlyGate(!appState.isSubscribed)
                .task {
                    await SubscriptionManager.shared.refreshEntitlement()
                    appState.entitlement = SubscriptionManager.shared.entitlement
                }
        }
    }
}

#Preview {
    let state = AppState()
    ContentView().environment(state)
}
