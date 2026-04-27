import SwiftUI

struct ConfigurationView: View {
    var appState: AppState
    @Environment(LocalStore.self) private var store
    @Environment(\.isReadOnly) private var isReadOnly

    @State private var isLoadingBows = false
    @State private var isLoadingArrows = false
    @State private var errorMessage: String?
    @State private var showAddBow = false
    @State private var showAddArrow = false
    @State private var showingPaywall = false
    @State private var pendingDeleteBow: Bow?
    @State private var pendingDeleteArrow: ArrowConfiguration?
    @State private var navigateToNewBow: Bow?
    @State private var pendingNavBow: Bow?
    @AppStorage(UnitSystem.storageKey) private var unitSystem: UnitSystem = .imperial

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Header
                BPNavHeader(eyebrow: "BOWPRESS \u{00B7} KIT", title: "Equipment") {
                    EmptyView()
                }

                VStack(alignment: .leading, spacing: 0) {
                    // BOWS section
                    bowsSection
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    // ARROWS section
                    arrowsSection
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                }
            }
        }
        .background(Color.appPaper)
        .navigationBarHidden(true)
        .navigationDestination(item: $navigateToNewBow) { bow in
            BowDetailView(bow: bow, appState: appState)
        }
        .sheet(isPresented: $showAddBow, onDismiss: {
            if let bow = pendingNavBow {
                navigateToNewBow = bow
                pendingNavBow = nil
            }
        }) {
            AddBowView(appState: appState, onCreated: { bow in pendingNavBow = bow })
        }
        .sheet(isPresented: $showAddArrow) { AddArrowView(appState: appState) }
        .sheet(isPresented: $showingPaywall) { NavigationStack { PaywallView() } }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(
            "Delete \(pendingDeleteBow?.name ?? "bow")?",
            isPresented: Binding(
                get: { pendingDeleteBow != nil },
                set: { if !$0 { pendingDeleteBow = nil } }
            ),
            presenting: pendingDeleteBow
        ) { bow in
            Button("Cancel", role: .cancel) { pendingDeleteBow = nil }
            Button("Delete", role: .destructive) {
                if let err = deleteBowEverywhere(bow, appState: appState, store: store) {
                    errorMessage = err.localizedDescription
                }
                pendingDeleteBow = nil
            }
        } message: { _ in
            Text("This permanently removes this bow along with its tuning history and shooting sessions. This cannot be undone.")
        }
        .alert(
            "Delete \(pendingDeleteArrow?.label ?? "arrow")?",
            isPresented: Binding(
                get: { pendingDeleteArrow != nil },
                set: { if !$0 { pendingDeleteArrow = nil } }
            ),
            presenting: pendingDeleteArrow
        ) { arrow in
            Button("Cancel", role: .cancel) { pendingDeleteArrow = nil }
            Button("Delete", role: .destructive) {
                if let err = deleteArrowEverywhere(arrow, appState: appState, store: store) {
                    errorMessage = err.localizedDescription
                }
                pendingDeleteArrow = nil
            }
        } message: { _ in
            Text("This permanently removes this arrow configuration. Past sessions that used it are preserved. This cannot be undone.")
        }
        .task { await loadAll() }
    }

    // MARK: - Bows section

    @ViewBuilder
    private var bowsSection: some View {
        // Section header row
        HStack(alignment: .center) {
            BPEyebrow("BOWS \u{00B7} \(appState.bows.count)")
            Spacer()
            BPEditLink("ADD") {
                if isReadOnly { showingPaywall = true }
                else { showAddBow = true }
            }
            .accessibilityIdentifier("add_bows_button")
        }
        .padding(.bottom, 10)

        // Bows card
        if isLoadingBows && appState.bows.isEmpty {
            BPCard(padding: 0) {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 20)
            }
        } else if appState.bows.isEmpty {
            BPCard(padding: 0) {
                Text("No bows yet")
                    .font(.bpUI(14))
                    .foregroundStyle(Color.appInk3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
            }
        } else {
            BPCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(appState.bows.enumerated()), id: \.element.id) { idx, bow in
                        let isLast = idx == appState.bows.count - 1
                        NavigationLink(destination: BowDetailView(bow: bow, appState: appState)) {
                            BowRow(bow: bow, isLast: isLast) {
                                if isReadOnly { showingPaywall = true }
                                else { pendingDeleteBow = bow }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("bow_row_\(bow.id)")
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button(role: .destructive) {
                                if isReadOnly { showingPaywall = true }
                                else { pendingDeleteBow = bow }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Arrows section

    @ViewBuilder
    private var arrowsSection: some View {
        HStack(alignment: .center) {
            BPEyebrow("ARROWS \u{00B7} \(appState.arrowConfigs.count)")
            Spacer()
            BPEditLink("ADD") {
                if isReadOnly { showingPaywall = true }
                else { showAddArrow = true }
            }
            .accessibilityIdentifier("add_arrows_button")
        }
        .padding(.bottom, 10)

        if isLoadingArrows && appState.arrowConfigs.isEmpty {
            BPCard(padding: 0) {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 20)
            }
        } else if appState.arrowConfigs.isEmpty {
            BPCard(padding: 0) {
                Text("No arrow setups yet")
                    .font(.bpUI(14))
                    .foregroundStyle(Color.appInk3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
            }
        } else {
            BPCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(appState.arrowConfigs.enumerated()), id: \.element.id) { idx, arrow in
                        let isLast = idx == appState.arrowConfigs.count - 1
                        NavigationLink(destination: ArrowDetailView(arrow: arrow, appState: appState)) {
                            ArrowRow(arrow: arrow, unitSystem: unitSystem, isLast: isLast)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .contextMenu {
                                Button(role: .destructive) {
                                    if isReadOnly { showingPaywall = true }
                                    else { pendingDeleteArrow = arrow }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }

    // MARK: - Data loading

    private func loadAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadBows() }
            group.addTask { await loadArrows() }
        }
    }

    private func loadBows() async {
        isLoadingBows = true
        do { appState.bows = try store.fetchBows() }
        catch { errorMessage = error.localizedDescription }
        isLoadingBows = false
    }

    private func loadArrows() async {
        isLoadingArrows = true
        do { appState.arrowConfigs = try store.fetchArrowConfigs() }
        catch { errorMessage = error.localizedDescription }
        isLoadingArrows = false
    }
}

// MARK: - BowRow

private struct BowRow: View {
    let bow: Bow
    let isLast: Bool
    let onDelete: () -> Void

    private var isActive: Bool { true } // active = most recently used; simplified
    private var isRetired: Bool { false } // retirement detection TBD

    private var specLine: String {
        var parts = [bow.bowType.label.uppercased()]
        return parts.joined(separator: " \u{00B7} ")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(bow.name)
                        .font(.bpDisplay(21, italic: true, weight: .medium))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)
                }
                Text(specLine)
                    .font(.bpMono(12))
                    .tracking(10 * 0.04)
                    .foregroundStyle(Color.appInk3)
            }
            Spacer(minLength: 8)
            Text("\u{203A}")
                .font(.bpDisplay(26, italic: true, weight: .medium))
                .foregroundStyle(Color.appPond)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .opacity(isRetired ? 0.55 : 1.0)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.appLine2)
                    .frame(height: 1)
            }
        }
    }
}

// MARK: - ArrowRow

private struct ArrowRow: View {
    let arrow: ArrowConfiguration
    let unitSystem: UnitSystem
    let isLast: Bool

    private var specLine: String {
        arrow.specSummary(system: unitSystem).uppercased()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(arrow.label)
                        .font(.bpDisplay(21, italic: true, weight: .medium))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)
                    BPStamp("ACTIVE", tone: .pond)
                }
                Text(specLine)
                    .font(.bpMono(12))
                    .tracking(10 * 0.04)
                    .foregroundStyle(Color.appInk3)
            }
            Spacer(minLength: 8)
            Text("\u{203A}")
                .font(.bpDisplay(26, italic: true, weight: .medium))
                .foregroundStyle(Color.appPond)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.appLine2)
                    .frame(height: 1)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let appState = AppState()
    appState.bows = [
        Bow(id: "b1", userId: "u1", name: "My Hoyt", brand: "Hoyt", model: "Carbon RX-8", createdAt: Date()),
    ]
    appState.arrowConfigs = [
        ArrowConfiguration(id: "a1", userId: "u1", label: "Match Arrows", brand: "Easton", model: "X10", length: 28.5, pointWeight: 110, fletchingType: .vane, fletchingLength: 2.0, fletchingOffset: 1.5, nockType: "pin", totalWeight: 420, notes: nil),
    ]
    return NavigationStack {
        ConfigurationView(appState: appState)
    }
}
