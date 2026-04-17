import SwiftUI

// MARK: - AnalyticsView

struct AnalyticsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = AnalyticsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.overview == nil {
                    loadingView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !appState.bows.isEmpty {
                        NavigationLink {
                            HistoricalSessionsView(
                                sessions: ShootingSession.mockSessions,
                                bowName: selectedBow?.name ?? "Bow"
                            )
                        } label: {
                            Label("History", systemImage: "list.bullet.clipboard")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
            }
        }
        .task {
            await initialLoad()
        }
    }

    // MARK: - Sub-views

    private var mainContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {

                // Bow picker (multi-bow only)
                if appState.bows.count > 1 {
                    bowPicker
                        .padding(.horizontal, 16)
                }

                // Period selector
                periodSelector
                    .padding(.horizontal, 16)

                // Error banner
                if let errorMessage = viewModel.error {
                    errorBanner(message: errorMessage)
                        .padding(.horizontal, 16)
                }

                // Content or empty state
                if let overview = viewModel.overview, overview.sessionCount > 0 {
                    analyticsContent(overview: overview)
                } else if !viewModel.isLoading {
                    emptyStateView
                        .padding(.horizontal, 16)
                }

                // Loading overlay while refreshing with stale data
                if viewModel.isLoading && viewModel.overview != nil {
                    HStack {
                        Spacer()
                        ProgressView("Refreshing…")
                            .controlSize(.small)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Bow picker

    private var bowPicker: some View {
        Picker("Bow", selection: Binding(
            get: { viewModel.selectedBowId ?? appState.bows.first?.id ?? "" },
            set: { newBowId in
                Task { await viewModel.load(bowId: newBowId, period: viewModel.selectedPeriod) }
            }
        )) {
            ForEach(appState.bows) { bow in
                Text(bow.name).tag(bow.id)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Period selector

    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AnalyticsPeriod.allCases, id: \.rawValue) { period in
                    PeriodPill(
                        label: period.label,
                        isSelected: viewModel.selectedPeriod == period
                    ) {
                        guard viewModel.selectedPeriod != period else { return }
                        Task {
                            if let bowId = viewModel.selectedBowId {
                                await viewModel.load(bowId: bowId, period: period)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Analytics content

    @ViewBuilder
    private func analyticsContent(overview: AnalyticsOverview) -> some View {
        // Period comparison card — first and full-width
        if let comparison = viewModel.comparison {
            PeriodComparisonCard(comparison: comparison)
                .padding(.horizontal, 16)
        }

        // Overview card
        OverviewCard(overview: overview)
            .padding(.horizontal, 16)

        // Score timeline
        let configs = BowConfiguration.mockConfigs.filter { $0.bowId == overview.bowId }
        if !configs.isEmpty {
            ScoreTimelineView(overview: overview, allConfigs: configs)
                .padding(.horizontal, 16)
        }

        // Suggestions section
        AnalyticsSuggestionsSection(
            suggestions: viewModel.suggestions,
            onMarkRead: { suggestion in
                await viewModel.markRead(suggestion)
            }
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)
            #if canImport(UIKit)
            LottieView(name: "empty_state")
                .frame(width: 100, height: 100)
            #else
            Image(systemName: "chart.bar.xaxis.ascending.badge.clock")
                .font(.system(size: 64))
                .foregroundStyle(.quaternary)
                .symbolEffect(.pulse)
            #endif
            Text("Not enough data yet")
                .font(.title3.weight(.semibold))
            Text("Log at least 6 arrows under a configuration to unlock analytics.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Loading view

    private var loadingView: some View {
        VStack {
            Spacer()
            #if canImport(UIKit)
            LottieView(name: "loading")
                .frame(width: 80, height: 80)
            #else
            ProgressView("Loading analytics…")
                .controlSize(.large)
            #endif
            Spacer()
        }
    }

    // MARK: - Error banner

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Failed to load analytics")
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Retry") {
                Task { await viewModel.refresh() }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var selectedBow: Bow? {
        appState.bows.first { $0.id == viewModel.selectedBowId }
        ?? appState.bows.first
    }

    private func initialLoad() async {
        guard let bow = appState.bows.first, viewModel.overview == nil else { return }
        await viewModel.load(bowId: bow.id, period: .week)
    }
}

// MARK: - PeriodPill

private struct PeriodPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.appAccent : Color.appSurface)
                        .shadow(color: isSelected ? Color.appAccent.opacity(0.3) : .clear,
                                radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Previews

#Preview("Loaded – high score") {
    let appState = AppState()
    appState.bows = [
        Bow(id: "b1", userId: "u1", name: "Hoyt RX7", brand: "Hoyt", model: "RX7", createdAt: .now),
        Bow(id: "b2", userId: "u1", name: "Mathews Phase4", brand: "Mathews", model: "Phase4", createdAt: .now),
    ]

    return AnalyticsViewPreviewWrapper(
        overview: .mockHighScore,
        suggestions: AnalyticsSuggestion.mockAllSuggestions
    )
    .environment(appState)
}

#Preview("Loaded – mid score") {
    let appState = AppState()
    appState.bows = [
        Bow(id: "b1", userId: "u1", name: "Hoyt RX7", brand: "Hoyt", model: "RX7", createdAt: .now),
    ]

    return AnalyticsViewPreviewWrapper(
        overview: .mockMidScore,
        suggestions: [AnalyticsSuggestion.mockUnread]
    )
    .environment(appState)
}

#Preview("Empty state") {
    let appState = AppState()
    appState.bows = [
        Bow(id: "b1", userId: "u1", name: "Hoyt RX7", brand: "Hoyt", model: "RX7", createdAt: .now),
    ]

    return AnalyticsViewPreviewWrapper(overview: nil, suggestions: [])
        .environment(appState)
}

#Preview("No bows") {
    let appState = AppState()
    AnalyticsViewPreviewWrapper(overview: nil, suggestions: [])
        .environment(appState)
}

/// Preview wrapper that injects pre-built state, bypassing async loading.
private struct AnalyticsViewPreviewWrapper: View {
    let overview: AnalyticsOverview?
    let suggestions: [AnalyticsSuggestion]

    @State private var viewModel = AnalyticsViewModel()
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.overview != nil || overview == nil {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            if appState.bows.count > 1 {
                                Picker("Bow", selection: .constant(appState.bows.first?.id ?? "")) {
                                    ForEach(appState.bows) { bow in
                                        Text(bow.name).tag(bow.id)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .padding(.horizontal, 16)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(AnalyticsPeriod.allCases, id: \.rawValue) { period in
                                        PeriodPill(
                                            label: period.label,
                                            isSelected: period == .week,
                                            action: {}
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }

                            if let ov = viewModel.overview ?? overview, ov.sessionCount > 0 {
                                OverviewCard(overview: ov)
                                    .padding(.horizontal, 16)
                                ScoreTimelineView(
                                    overview: ov,
                                    allConfigs: BowConfiguration.mockConfigs
                                )
                                .padding(.horizontal, 16)
                                AnalyticsSuggestionsSection(suggestions: viewModel.suggestions)
                                    .padding(.horizontal, 16)
                            } else {
                                VStack(spacing: 20) {
                                    Spacer(minLength: 40)
                                    #if canImport(UIKit)
                                    LottieView(name: "empty_state")
                                        .frame(width: 100, height: 100)
                                    #else
                                    Image(systemName: "chart.bar.xaxis.ascending.badge.clock")
                                        .font(.system(size: 64))
                                        .foregroundStyle(.quaternary)
                                    #endif
                                    Text("Not enough data yet")
                                        .font(.title3.weight(.semibold))
                                    Text("Log at least 6 arrows under a configuration to unlock analytics.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 16)
                                    Spacer(minLength: 40)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                } else {
                    VStack {
                        Spacer()
                        #if canImport(UIKit)
                        LottieView(name: "loading")
                            .frame(width: 80, height: 80)
                        #else
                        ProgressView("Loading analytics…").controlSize(.large)
                        #endif
                        Spacer()
                    }
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            viewModel.overview = overview
            viewModel.suggestions = suggestions
            viewModel.selectedBowId = appState.bows.first?.id
        }
    }
}
