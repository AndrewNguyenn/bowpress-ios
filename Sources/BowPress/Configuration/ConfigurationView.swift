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

    var body: some View {
        List {
            Section {
                if isLoadingBows && appState.bows.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if appState.bows.isEmpty {
                    Text("No bows yet")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(appState.bows) { bow in
                        NavigationLink(destination: BowDetailView(bow: bow, appState: appState)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bow.name).font(.body.weight(.semibold))
                                Text(bow.bowType.label).font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .accessibilityIdentifier("bow_row_\(bow.id)")
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if isReadOnly { showingPaywall = true }
                                else { pendingDeleteBow = bow }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                sectionHeader(title: "Bows", systemImage: "scope") {
                    if isReadOnly { showingPaywall = true }
                    else { showAddBow = true }
                }
            }

            Section {
                if isLoadingArrows && appState.arrowConfigs.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if appState.arrowConfigs.isEmpty {
                    Text("No arrow setups yet")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(appState.arrowConfigs) { arrow in
                        NavigationLink(destination: ArrowDetailView(arrow: arrow, appState: appState)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(arrow.label).font(.body.weight(.semibold))
                                Text("\(String(format: "%.2f", arrow.length))\" · \(arrow.pointWeight)gr point")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if isReadOnly { showingPaywall = true }
                                else { pendingDeleteArrow = arrow }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                sectionHeader(title: "Arrows", systemImage: "arrow.right") {
                    if isReadOnly { showingPaywall = true }
                    else { showAddArrow = true }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Equipment")
        .navigationBarTitleDisplayMode(.inline)
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

    @ViewBuilder
    private func sectionHeader(title: String, systemImage: String, onAdd: @escaping () -> Void) -> some View {
        HStack {
            Label(title, systemImage: systemImage).font(.headline)
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(title)")
            .accessibilityIdentifier("add_\(title.lowercased())_button")
        }
        .textCase(nil)
    }

    // MARK: - Data

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
