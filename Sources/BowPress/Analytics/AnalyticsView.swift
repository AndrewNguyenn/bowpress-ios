import SwiftUI

// MARK: - AnalyticsView

struct AnalyticsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = AnalyticsViewModel()
    @State private var selectedPeriod: AnalyticsPeriod = .threeDays

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.overview == nil {
                loadingView
            } else {
                mainContent
            }
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !appState.bows.isEmpty {
                    NavigationLink {
                        HistoricalSessionsView(
                            sessions: ShootingSession.mockSessions,
                            bowName: "All Bows"
                        )
                    } label: {
                        Label("History", systemImage: "list.bullet.clipboard")
                            .labelStyle(.iconOnly)
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
            VStack(alignment: .leading, spacing: 16) {

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

    // MARK: - Period selector

    private var periodSelector: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                Text(period.label).tag(period)
            }
        }
        .pickerStyle(.menu)
        .tint(Color.appAccent)
        .onChange(of: selectedPeriod) { _, period in
            Task { await viewModel.load(period: period) }
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
        ScoreTimelineView(overview: overview, allConfigs: BowConfiguration.mockConfigs)
            .padding(.horizontal, 16)

        // Trend insights
        if let comparison = viewModel.comparison {
            AnalyticsTrendInsightsSection(comparison: comparison, overview: overview)
                .padding(.horizontal, 16)
        }

        // Bow tuning suggestions
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

    private func initialLoad() async {
        guard viewModel.overview == nil else { return }
        await viewModel.load(period: .threeDays)
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
                        VStack(alignment: .leading, spacing: 16) {
                            Picker("Period", selection: .constant(AnalyticsPeriod.threeDays)) {
                                ForEach(AnalyticsPeriod.allCases, id: \.self) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .tint(Color.appAccent)
                            .padding(.horizontal, 16)

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
        }
    }
}
