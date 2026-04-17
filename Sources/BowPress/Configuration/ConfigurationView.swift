import SwiftUI

struct ConfigurationView: View {
    var appState: AppState

    @State private var isLoadingBows = false
    @State private var isLoadingArrows = false
    @State private var errorMessage: String?
    @State private var showAddBow = false
    @State private var showAddArrow = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // MARK: Bows (top half)
                VStack(spacing: 0) {
                    sectionHeader(title: "Bows", systemImage: "scope") {
                        showAddBow = true
                    }
                    Divider()
                    if isLoadingBows && appState.bows.isEmpty {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if appState.bows.isEmpty {
                        emptyState(message: "No bows yet")
                    } else {
                        List {
                            ForEach(appState.bows) { bow in
                                NavigationLink(destination: BowDetailView(bow: bow, appState: appState)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bow.name)
                                            .font(.body.weight(.semibold))
                                        Text("\(bow.brand) \(bow.model)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .onDelete(perform: deleteBow)
                        }
                        .listStyle(.plain)
                    }
                }
                .frame(height: geo.size.height / 2)

                Divider()
                    .background(Color.appBorder)

                // MARK: Arrows (bottom half)
                VStack(spacing: 0) {
                    sectionHeader(title: "Arrows", systemImage: "arrow.right") {
                        showAddArrow = true
                    }
                    Divider()
                    if isLoadingArrows && appState.arrowConfigs.isEmpty {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if appState.arrowConfigs.isEmpty {
                        emptyState(message: "No arrow setups yet")
                    } else {
                        List {
                            ForEach(appState.arrowConfigs) { arrow in
                                NavigationLink(destination: ArrowDetailView(arrow: arrow, appState: appState)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(arrow.label)
                                            .font(.body.weight(.semibold))
                                        Text("\(String(format: "%.2f", arrow.length))\" · \(arrow.pointWeight)gr point")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .onDelete(perform: deleteArrow)
                        }
                        .listStyle(.plain)
                    }
                }
                .frame(height: geo.size.height / 2)
            }
        }
        .navigationTitle("Configure")
        .sheet(isPresented: $showAddBow) {
            AddBowView(appState: appState)
        }
        .sheet(isPresented: $showAddArrow) {
            AddArrowView(appState: appState)
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task { await loadAll() }
    }

    @ViewBuilder
    private func sectionHeader(title: String, systemImage: String, onAdd: @escaping () -> Void) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.headline)
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appBackground)
    }

    @ViewBuilder
    private func emptyState(message: String) -> some View {
        Spacer()
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.tertiary)
        Spacer()
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
        do { appState.bows = try await APIClient.shared.fetchBows() }
        catch { errorMessage = error.localizedDescription }
        isLoadingBows = false
    }

    private func loadArrows() async {
        isLoadingArrows = true
        do { appState.arrowConfigs = try await APIClient.shared.fetchArrowConfigs() }
        catch { errorMessage = error.localizedDescription }
        isLoadingArrows = false
    }

    private func deleteBow(at offsets: IndexSet) {
        let toDelete = offsets.map { appState.bows[$0] }
        appState.bows.remove(atOffsets: offsets)
        Task {
            for bow in toDelete {
                do { try await APIClient.shared.deleteBow(id: bow.id) }
                catch { appState.bows.append(bow); errorMessage = error.localizedDescription }
            }
        }
    }

    private func deleteArrow(at offsets: IndexSet) {
        let toDelete = offsets.map { appState.arrowConfigs[$0] }
        appState.arrowConfigs.remove(atOffsets: offsets)
        Task {
            for arrow in toDelete {
                do { try await APIClient.shared.deleteArrowConfig(id: arrow.id) }
                catch { appState.arrowConfigs.append(arrow); errorMessage = error.localizedDescription }
            }
        }
    }
}

#Preview {
    let appState = AppState()
    appState.bows = [
        Bow(id: "b1", userId: "u1", name: "My Hoyt", brand: "Hoyt", model: "Carbon RX-8", createdAt: Date()),
        Bow(id: "b2", userId: "u1", name: "Training Bow", brand: "Mathews", model: "Phase4 29", createdAt: Date())
    ]
    appState.arrowConfigs = [
        ArrowConfiguration(id: "a1", userId: "u1", label: "Match Arrows", brand: "Easton", model: "X10", length: 28.5, pointWeight: 110, fletchingType: .vane, fletchingLength: 2.0, fletchingOffset: 1.5, nockType: "pin", totalWeight: 420, notes: nil),
        ArrowConfiguration(id: "a2", userId: "u1", label: "Practice", brand: "Gold Tip", model: "Hunter XT", length: 29.0, pointWeight: 100, fletchingType: .vane, fletchingLength: 2.25, fletchingOffset: 2.0, nockType: nil, totalWeight: nil, notes: nil)
    ]
    return NavigationStack {
        ConfigurationView(appState: appState)
    }
}
