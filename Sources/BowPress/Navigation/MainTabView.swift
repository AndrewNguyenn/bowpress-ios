import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocalStore.self) private var store
    @State private var sessionViewModel = SessionViewModel()
    @State private var selectedTab = MainTabView.initialTabFromLaunchArgs()

    // Allows Maestro flows to start directly on a specific tab, bypassing a
    // SwiftUI/iOS-18 issue where tab-bar taps sometimes don't switch
    // selection reliably. Passed via Maestro's launchApp arguments (iOS
    // routes -key value launch args into NSUserDefaults) or via raw argv
    // for backwards compatibility with older harnesses.
    private static func initialTabFromLaunchArgs() -> Int {
        let ud = UserDefaults.standard.integer(forKey: "StartTab")
        if (0...4).contains(ud) && ud != 0 { return ud }
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-StartTab"), idx + 1 < args.count,
           let n = Int(args[idx + 1]), (0...4).contains(n) { return n }
        return 0
    }
    @State private var syncService = BackgroundSyncService()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                AnalyticsView()
                    .safeAreaInset(edge: .top, spacing: 0) { sessionBanner }
            }
            .tabItem { Label("Analytics", systemImage: "chart.bar.xaxis") }
            .tag(0)

            NavigationStack {
                HistoricalSessionsView(
                    sessions: appState.completedSessions,
                    bowName: "All Bows",
                    allConfigs: Array(appState.bowConfigs.values)
                )
                .safeAreaInset(edge: .top, spacing: 0) { sessionBanner }
            }
            .tabItem { Label("Log", systemImage: "list.bullet.clipboard") }
            .tag(1)

            NavigationStack {
                SessionView(appState: appState, viewModel: sessionViewModel)
            }
            .tabItem { Label("Session", systemImage: "target") }
            .tag(2)

            NavigationStack {
                ConfigurationView(appState: appState)
                    .safeAreaInset(edge: .top, spacing: 0) { sessionBanner }
            }
            .tabItem { Label("Equipment", systemImage: "slider.horizontal.3") }
            .tag(3)

            NavigationStack {
                SettingsView()
                    .safeAreaInset(edge: .top, spacing: 0) { sessionBanner }
            }
            .tabItem { Label("Settings", systemImage: "person.crop.circle") }
            .tag(4)
        }
        .tint(.appAccent)
        .onChange(of: appState.bowConfigs) { _, newConfigs in
            // Forward equipment-tab config saves into the active session so the banner
            // and Change sheet reflect the update without requiring a manual re-apply.
            guard sessionViewModel.isSessionActive,
                  let bowId = sessionViewModel.selectedBow?.id,
                  let updated = newConfigs[bowId] else { return }
            let alreadyActive = sessionViewModel.activeBowConfig?.id == updated.id
            let alreadyPending = sessionViewModel.pendingBowConfig?.id == updated.id
            guard !alreadyActive && !alreadyPending else { return }
            sessionViewModel.applyConfigChange(bowConfig: updated, arrowConfig: nil)
        }
        .task {
            sessionViewModel.store = store
            sessionViewModel.onConfigConfirmed = { bowId, config in
                appState.bowConfigs[bowId] = config
            }
            sessionViewModel.onSessionCompleted = { completed in
                appState.completedSessions.insert(completed, at: 0)
            }
            syncService.configure(store: store)
            syncService.triggerSync()

            // Run hydration and a minimum splash-display timer in parallel so
            // the animation never flashes away instantly — even when the
            // in-memory DEBUG seed is basically free.
            async let minDisplay: Void = {
                try? await Task.sleep(for: .milliseconds(1600))
            }()
            async let hydration: Void = {
                #if DEBUG
                await DevAutoSignIn.ensureSignedIn()
                #endif
                await LocalHydration.hydrateFromAPI(store: store, api: APIClient.shared)
            }()
            _ = await (minDisplay, hydration)

            appState.bows = (try? store.fetchBows()) ?? appState.bows
            appState.arrowConfigs = (try? store.fetchArrowConfigs()) ?? appState.arrowConfigs
            appState.completedSessions = (try? store.fetchSessions()) ?? appState.completedSessions

            // Resume an in-progress session if the user closed the app mid-shoot.
            // Archery practices can run long and phones die; the session row and
            // its arrows/ends were written to LocalStore as they happened, so
            // we can reconstruct ViewModel state from disk.
            if !sessionViewModel.isSessionActive,
               let active = try? store.fetchActiveSession(),
               let bow = appState.bows.first(where: { $0.id == active.bowId }),
               let arrowConfig = appState.arrowConfigs.first(where: { $0.id == active.arrowConfigId }) {
                let configs = (try? store.fetchConfigurations(bowId: bow.id)) ?? []
                if let bowConfig = configs.first(where: { $0.id == active.bowConfigId }) {
                    sessionViewModel.resume(
                        session: active,
                        bow: bow,
                        bowConfig: bowConfig,
                        arrowConfig: arrowConfig,
                        knownConfigs: configs
                    )
                }
            }

            // Hydration ran in parallel with AnalyticsView.task's initial load,
            // so the first overview query against the store was empty. Bump the
            // refresh nonce — AnalyticsView listens for this and re-loads.
            appState.analyticsRefreshNonce += 1

            withAnimation(.easeInOut(duration: 0.45)) {
                appState.isHydrating = false
            }
        }
    }

    @ViewBuilder
    private var sessionBanner: some View {
        if sessionViewModel.isSessionActive {
            ActiveSessionBanner(viewModel: sessionViewModel) {
                selectedTab = 2
            }
        }
    }
}

// MARK: - Active Session Banner

private struct ActiveSessionBanner: View {
    var viewModel: SessionViewModel
    var onTap: () -> Void

    /// Drives the pulsing maple dot. Flips every second so the animation
    /// has a value to interpolate on.
    @State private var pulseOn: Bool = false
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.appMaple)
                    .frame(width: 8, height: 8)
                    .opacity(pulseOn ? 1.0 : 0.35)
                    .animation(.easeInOut(duration: 1.0), value: pulseOn)

                Text("IN SESSION")
                    .font(.bpUI(11.5, weight: .semibold))
                    .appTracking(0.22, at: 10)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.appPondDk)

                Text("· \(viewModel.selectedBow?.name ?? "session") · \(viewModel.allArrows.count) arrow\(viewModel.allArrows.count == 1 ? "" : "s")")
                    .font(.bpUI(14))
                    .foregroundStyle(Color.appInk3)
                    .lineLimit(1)

                Spacer()

                Text("\u{203A}")
                    .font(.bpDisplay(20, italic: true, weight: .medium))
                    .foregroundStyle(Color.appPondDk)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.appPaper2)
            .overlay(
                Rectangle()
                    .fill(Color.appLine)
                    .frame(height: 1),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
        .onReceive(tick) { _ in pulseOn.toggle() }
    }
}

#Preview {
    let appState = AppState()
    appState.isAuthenticated = true
    return MainTabView()
        .environment(appState)
}
