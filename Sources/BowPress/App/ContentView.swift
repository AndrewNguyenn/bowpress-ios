import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.isAuthenticated {
            MainTabView()
        } else {
            AuthView()
        }
    }
}

#Preview {
    let state = AppState()
    ContentView()
        .environment(state)
}
