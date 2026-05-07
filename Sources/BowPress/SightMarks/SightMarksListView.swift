import SwiftUI

/// Per-bow sight marks list. Reached from `BowDetailView` via a
/// NavigationLink. Marks render in distance order (always); the
/// suggestion fit + visualisation only appear once the gating rules
/// are satisfied.
struct SightMarksListView: View {
    var bow: Bow

    @Environment(LocalStore.self) private var store
    @Environment(\.isReadOnly) private var isReadOnly
    @AppStorage(UnitSystem.storageKey) private var unitSystem: UnitSystem = .imperial

    @State private var marks: [SightMark] = []
    @State private var editingMark: SightMark? = nil
    @State private var isAdding = false
    @State private var showingPaywall = false
    @State private var errorMessage: String?

    private var measuredMarks: [SightMark] { marks.filter { !$0.isSuggestion } }

    var body: some View {
        List {
            if measuredMarks.count >= SightMarkSuggester.minMarkCount {
                Section {
                    SightMarksChart(marks: measuredMarks, unit: DistanceUnit.preferred(for: unitSystem))
                        .frame(height: 180)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                } header: {
                    Text("Calibration curve")
                } footer: {
                    Text(footerText)
                        .font(.footnote)
                }
            } else {
                Section {
                    GuidancePanel(measuredCount: measuredMarks.count)
                }
            }

            Section("Marks") {
                if marks.isEmpty {
                    Text("No marks yet — tap + to add your first one.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(marks) { mark in
                        Button {
                            if isReadOnly { showingPaywall = true } else { editingMark = mark }
                        } label: {
                            SightMarkRow(mark: mark)
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete(perform: isReadOnly ? nil : delete)
                }
            }
        }
        .navigationTitle("Sight Marks")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if isReadOnly { showingPaywall = true } else { isAdding = true }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            SightMarkEditSheet(
                mode: .add(bow: bow),
                existingMarks: measuredMarks
            )
        }
        .sheet(item: $editingMark) { mark in
            SightMarkEditSheet(
                mode: .edit(mark: mark, bow: bow),
                existingMarks: measuredMarks.filter { $0.id != mark.id }
            )
        }
        .sheet(isPresented: $showingPaywall) {
            NavigationStack { PaywallView() }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear(perform: reload)
        .onChange(of: editingMark) { _, _ in reload() }
        .onChange(of: isAdding) { _, _ in reload() }
    }

    private var footerText: String {
        let n = measuredMarks.count
        let countLabel = "\(n) measured mark\(n == 1 ? "" : "s")"
        return "\(countLabel). Suggestions kick in for distances inside the marked range. Outliers stand out from the curve — re-shoot if a mark looks off."
    }

    private func reload() {
        do {
            marks = try store.fetchSightMarks(bowId: bow.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let id = marks[index].id
            do {
                try store.deleteSightMark(id: id)
                SyncService().syncDeleteSightMark(id: id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        reload()
    }
}

// MARK: - Row

private struct SightMarkRow: View {
    var mark: SightMark
    @AppStorage(UnitSystem.storageKey) private var unitSystem: UnitSystem = .imperial

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(distanceLabel)
                    .font(.body.weight(.semibold))
                if let note = mark.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(markLabel)
                .font(.body.monospacedDigit())
                .foregroundStyle(mark.isSuggestion ? Color.secondary : Color.primary)
            if mark.isSuggestion {
                Text("suggested")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var distanceLabel: String {
        let formatted: String
        if mark.distance == mark.distance.rounded() {
            formatted = String(format: "%.0f", mark.distance)
        } else {
            formatted = String(format: "%.1f", mark.distance)
        }
        return "\(formatted) \(mark.distanceUnit.shortLabel)"
    }

    private var markLabel: String {
        String(format: "%.2f", mark.mark)
    }
}

// MARK: - Guidance for under-3 marks state

private struct GuidancePanel: View {
    var measuredCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "ruler")
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var title: String {
        "Suggestions need 3 marks"
    }

    private var detail: String {
        let need = SightMarkSuggester.minMarkCount - measuredCount
        if need > 0 {
            return "Add \(need) more measured mark\(need == 1 ? "" : "s") spanning at least 20 yards. Below that the fit isn't reliable — industry consensus."
        }
        return "Spread your marks at least 20 yards (max minus min) so the fit has enough curvature to interpolate honestly."
    }
}
