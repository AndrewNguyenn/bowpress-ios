import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = DashboardViewModel()
    @State private var selectedSuggestion: AnalyticsSuggestion?

    // Total unread count across all loaded suggestions
    private var unreadCount: Int {
        viewModel.suggestions.filter { !$0.wasRead }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.suggestions.isEmpty {
                    loadingView
                } else {
                    contentView
                }
            }
            .navigationTitle("BowPress")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.load(bows: appState.bows)
            }
            .sheet(item: $selectedSuggestion) { suggestion in
                SuggestionDetailView(suggestion: suggestion, viewModel: viewModel)
            }
        }
        .task {
            await viewModel.load(bows: appState.bows)
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack {
            Spacer()
            #if canImport(UIKit)
            LottieView(name: "loading")
                .frame(width: 80, height: 80)
            #else
            ProgressView("Loading insights…")
                .controlSize(.large)
            #endif
            Spacer()
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.groupedSuggestions.isEmpty {
            emptyStateView
        } else {
            List {
                // Summary banner
                summaryBanner
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                // Grouped suggestion rows
                ForEach(viewModel.groupedSuggestions, id: \.bowId) { group in
                    Section {
                        ForEach(group.suggestions) { suggestion in
                            SuggestionCard(suggestion: suggestion)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .onTapGesture {
                                    selectedSuggestion = suggestion
                                }
                        }
                    } header: {
                        Text(bowName(for: group.bowId))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.plain)
            .animation(.easeInOut(duration: 0.35), value: viewModel.suggestions.map(\.wasRead))
        }
    }

    private var summaryBanner: some View {
        Group {
            if unreadCount == 0 {
                BannerView(
                    icon: "checkmark.circle.fill",
                    title: "All caught up",
                    subtitle: "No new insights at the moment.",
                    tint: .green
                )
            } else {
                BannerView(
                    icon: "sparkles",
                    title: "\(unreadCount) new \(unreadCount == 1 ? "insight" : "insights")",
                    subtitle: "Tap a card to review and apply.",
                    tint: .accentColor
                )
            }
        }
        .animation(.easeInOut(duration: 0.4), value: unreadCount)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            #if canImport(UIKit)
            LottieView(name: "empty_state")
                .frame(width: 100, height: 100)
            #else
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.circle")
                .font(.system(size: 64))
                .foregroundStyle(.quaternary)
                .symbolEffect(.pulse)
            #endif
            Text("No suggestions yet")
                .font(.title3.weight(.semibold))
            Text("Keep logging sessions and we'll surface insights here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func bowName(for bowId: String) -> String {
        appState.bows.first(where: { $0.id == bowId })?.name ?? bowId
    }
}

// MARK: - Banner view

private struct BannerView: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(tint)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                .fill(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                        .strokeBorder(tint.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

// MARK: - Previews

#Preview("With suggestions") {
    let appState = AppState()
    appState.isAuthenticated = true
    appState.bows = [
        Bow(id: "b1", userId: "u1", name: "Hoyt RX7", brand: "Hoyt", model: "RX7", createdAt: .now),
        Bow(id: "b2", userId: "u1", name: "Mathews Phase4", brand: "Mathews", model: "Phase4", createdAt: .now),
    ]

    let vm = DashboardViewModel()
    vm.suggestions = AnalyticsSuggestion.mockAllSuggestions

    return DashboardViewPreviewWrapper(viewModel: vm)
        .environment(appState)
}

#Preview("Empty state") {
    let appState = AppState()
    appState.isAuthenticated = true

    let vm = DashboardViewModel()
    // No suggestions loaded

    return DashboardViewPreviewWrapper(viewModel: vm)
        .environment(appState)
}

#Preview("All caught up") {
    let appState = AppState()
    appState.isAuthenticated = true
    appState.bows = [
        Bow(id: "b1", userId: "u1", name: "Hoyt RX7", brand: "Hoyt", model: "RX7", createdAt: .now),
    ]

    let vm = DashboardViewModel()
    vm.suggestions = AnalyticsSuggestion.mockAllSuggestions.map { s in
        var copy = s; copy.wasRead = true; return copy
    }

    return DashboardViewPreviewWrapper(viewModel: vm)
        .environment(appState)
}

/// Thin wrapper that injects a pre-built view model so previews bypass async loading.
private struct DashboardViewPreviewWrapper: View {
    @State var viewModel: DashboardViewModel
    @Environment(AppState.self) private var appState
    @State private var selectedSuggestion: AnalyticsSuggestion?

    private var unreadCount: Int { viewModel.suggestions.filter { !$0.wasRead }.count }

    var body: some View {
        NavigationStack {
            List {
                bannerRow
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                ForEach(viewModel.groupedSuggestions, id: \.bowId) { group in
                    Section {
                        ForEach(group.suggestions) { suggestion in
                            SuggestionCard(suggestion: suggestion)
                                .onTapGesture { selectedSuggestion = suggestion }
                        }
                    } header: {
                        Text(bowName(for: group.bowId))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("BowPress")
            .sheet(item: $selectedSuggestion) { s in
                SuggestionDetailView(suggestion: s, viewModel: viewModel)
            }
            .overlay {
                if viewModel.groupedSuggestions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.circle")
                            .font(.system(size: 64))
                            .foregroundStyle(.quaternary)
                        Text("No suggestions yet")
                            .font(.title3.weight(.semibold))
                        Text("Keep logging sessions and we'll surface insights here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
            }
        }
    }

    private var bannerRow: some View {
        Group {
            if unreadCount == 0 && !viewModel.groupedSuggestions.isEmpty {
                BannerView(
                    icon: "checkmark.circle.fill",
                    title: "All caught up",
                    subtitle: "No new insights at the moment.",
                    tint: .green
                )
            } else if unreadCount > 0 {
                BannerView(
                    icon: "sparkles",
                    title: "\(unreadCount) new \(unreadCount == 1 ? "insight" : "insights")",
                    subtitle: "Tap a card to review and apply.",
                    tint: .accentColor
                )
            }
        }
    }

    private func bowName(for bowId: String) -> String {
        appState.bows.first(where: { $0.id == bowId })?.name ?? bowId
    }
}
