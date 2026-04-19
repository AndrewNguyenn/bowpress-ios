import SwiftUI

// MARK: - AnalyticsView

struct AnalyticsView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocalStore.self) private var store
    @State private var viewModel = AnalyticsViewModel()
    @State private var selectedPeriod: AnalyticsPeriod = .threeDays
    @State private var highlightedSuggestionId: String?

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
        .task {
            await initialLoad()
        }
        .onChange(of: appState.analyticsRefreshNonce) { _, _ in
            Task { await viewModel.refresh() }
        }
    }

    // MARK: - Sub-views

    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Period selector
                    periodSelector

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
            .onChange(of: appState.pendingAnalyticsNavigation) { _, intent in
                scrollToIntent(intent, proxy: proxy)
            }
        }
    }

    private func scrollToIntent(_ intent: SuggestionNavigationIntent?, proxy: ScrollViewProxy) {
        guard case .suggestion(let id, _) = intent else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            proxy.scrollTo(id, anchor: .top)
        }
        highlightedSuggestionId = id
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            await MainActor.run {
                highlightedSuggestionId = nil
                appState.pendingAnalyticsNavigation = nil
            }
        }
    }

    // MARK: - Period selector

    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                    let selected = period == selectedPeriod
                    Button {
                        guard period != selectedPeriod else { return }
                        selectedPeriod = period
                        Task {
                            viewModel.configure(store: store, appState: appState)
                            await viewModel.load(period: period)
                        }
                    } label: {
                        Text(period.label)
                            .font(.subheadline.weight(selected ? .semibold : .regular))
                            .foregroundStyle(selected ? .white : Color.appAccent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selected ? Color.appAccent : Color.appAccent.opacity(0.1),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: selectedPeriod)
                }
            }
            .padding(.horizontal, 16)
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
            AnalyticsTrendInsightsSection(
                comparison: comparison,
                overview: overview,
                extraInsights: viewModel.extraInsights
            )
            .padding(.horizontal, 16)
        }

        // Spec §Analysis Outputs #3 and #4 — Change Impact Cards + Subjective-Objective
        // Correlation. Both are per-bow; we show them for the user's primary (first) bow.
        // When no bow exists, sections hide themselves via empty-state copy.
        if let bowId = appState.bows.first?.id {
            ChangeImpactCardsSection(bowId: bowId)
                .padding(.horizontal, 16)
            TagCorrelationsSection(bowId: bowId)
                .padding(.horizontal, 16)
        }

        // Bow tuning suggestions
        AnalyticsSuggestionsSection(
            suggestions: viewModel.suggestions,
            highlightedId: highlightedSuggestionId,
            onMarkRead: { suggestion in
                await viewModel.markRead(suggestion)
            },
            onDismiss: { suggestion in
                await viewModel.dismiss(suggestion)
            },
            viewModel: viewModel
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
        viewModel.configure(store: store, appState: appState)
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
