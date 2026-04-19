import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var sessionViewModel = SessionViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                AnalyticsView()
                    .safeAreaInset(edge: .top, spacing: 0) { sessionBanner }
            }
            .tabItem { Label("Analytics", systemImage: "chart.bar.xaxis") }
            .tag(0)

            NavigationStack {
                SessionView(appState: appState, viewModel: sessionViewModel)
            }
            .tabItem { Label("Session", systemImage: "target") }
            .tag(1)

            NavigationStack {
                ConfigurationView(appState: appState)
                    .safeAreaInset(edge: .top, spacing: 0) { sessionBanner }
            }
            .tabItem { Label("Equipment", systemImage: "slider.horizontal.3") }
            .tag(2)

            NavigationStack {
                SettingsView()
                    .safeAreaInset(edge: .top, spacing: 0) { sessionBanner }
            }
            .tabItem { Label("Settings", systemImage: "person.crop.circle") }
            .tag(3)
        }
        .tint(.appAccent)
    }

    @ViewBuilder
    private var sessionBanner: some View {
        if sessionViewModel.isSessionActive {
            ActiveSessionBanner(viewModel: sessionViewModel) {
                selectedTab = 1
            }
        }
    }
}

// MARK: - Active Session Banner

private struct ActiveSessionBanner: View {
    var viewModel: SessionViewModel
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Session in progress")
                        .font(.subheadline).fontWeight(.semibold)
                    if let bow = viewModel.selectedBow {
                        Text(bow.name)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("\(viewModel.allArrows.count) arrow\(viewModel.allArrows.count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundStyle(.separator),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let appState = AppState()
    appState.isAuthenticated = true
    return MainTabView()
        .environment(appState)
}
