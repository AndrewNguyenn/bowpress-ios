import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var sessionViewModel = SessionViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("Dashboard", systemImage: "house.fill") }
            .badge(appState.unreadSuggestionCount > 0 ? appState.unreadSuggestionCount : 0)

            NavigationStack {
                ConfigurationView(appState: appState)
            }
            .tabItem { Label("Configure", systemImage: "slider.horizontal.3") }

            NavigationStack {
                SessionView(appState: appState, viewModel: sessionViewModel)
            }
            .tabItem { Label("Session", systemImage: "scope") }

            NavigationStack {
                AnalyticsView()
            }
            .tabItem { Label("Analytics", systemImage: "chart.bar.xaxis") }
        }
        .tint(.appAccent)
    }
}

#Preview {
    let appState = AppState()
    appState.isAuthenticated = true
    return MainTabView()
        .environment(appState)
}
