import SwiftUI

struct ArrowDetailView: View {
    var arrow: ArrowConfiguration
    var appState: AppState

    @Environment(LocalStore.self) private var store

    @State private var label = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var length: Double = 28.0
    @State private var pointWeight: Int = 100
    @State private var fletchingType: ArrowConfiguration.FletchingType = .vane
    @State private var fletchingLength: Double = 2.0
    @State private var fletchingOffset: Double = 1.5
    @State private var nockType = ""
    @State private var totalWeightText = ""
    @State private var shaftDiameter: ArrowConfiguration.ShaftDiameter? = nil
    @State private var notes = ""

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSavedBanner = false
    @State private var showDeleteConfirm = false
    @State private var showingPaywall = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.isReadOnly) private var isReadOnly

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("Label") {
                    TextField("Required", text: $label)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Brand") {
                    TextField("Optional", text: $brand)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Model") {
                    TextField("Optional", text: $model)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Shaft") {
                Stepper(value: $length, in: 18.0...36.0, step: 0.25) {
                    LabeledContent("Length", value: "\(String(format: "%.2f", length))\"")
                }
                Stepper(value: $pointWeight, in: 50...300, step: 5) {
                    LabeledContent("Point Weight", value: "\(pointWeight) gr")
                }
                Picker("Diameter", selection: $shaftDiameter) {
                    Text("Not set").tag(ArrowConfiguration.ShaftDiameter?.none)
                    ForEach(ArrowConfiguration.ShaftDiameter.allCases, id: \.self) { d in
                        Text(d.displayName).tag(ArrowConfiguration.ShaftDiameter?.some(d))
                    }
                }
            }

            Section("Fletching") {
                Picker("Type", selection: $fletchingType) {
                    ForEach(ArrowConfiguration.FletchingType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
                Stepper(value: $fletchingLength, in: 1.0...5.0, step: 0.25) {
                    LabeledContent("Length", value: "\(String(format: "%.2f", fletchingLength))\"")
                }
                Stepper(value: $fletchingOffset, in: 0.0...10.0, step: 0.5) {
                    LabeledContent("Offset", value: "\(String(format: "%.1f", fletchingOffset))°")
                }
            }

            Section("Nock & Weight") {
                LabeledContent("Nock Type") {
                    TextField("Optional", text: $nockType)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Total Weight (gr)") {
                    TextField("Optional", text: $totalWeightText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
            }

            Section {
                Button(role: .destructive) {
                    if isReadOnly { showingPaywall = true } else { showDeleteConfirm = true }
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete Arrow").foregroundStyle(.red)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(arrow.label)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") {
                        if isReadOnly { showingPaywall = true } else { Task { await save() } }
                    }
                    .fontWeight(.semibold)
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Delete \(arrow.label)?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { showDeleteConfirm = false }
            Button("Delete", role: .destructive) {
                if let err = deleteArrowEverywhere(arrow, appState: appState, store: store) {
                    errorMessage = err.localizedDescription
                } else {
                    dismiss()
                }
            }
        } message: {
            Text("This permanently removes this arrow configuration. Past sessions that used it are preserved. This cannot be undone.")
        }
        .sheet(isPresented: $showingPaywall) {
            NavigationStack { PaywallView() }
        }
        .overlay(alignment: .top) {
            if showSavedBanner {
                saveBanner
            }
        }
        .onAppear {
            seedFromArrow()
        }
    }

    private var saveBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Saved")
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .shadow(radius: 4)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func seedFromArrow() {
        label = arrow.label
        brand = arrow.brand ?? ""
        model = arrow.model ?? ""
        length = arrow.length
        pointWeight = arrow.pointWeight
        fletchingType = arrow.fletchingType
        fletchingLength = arrow.fletchingLength
        fletchingOffset = arrow.fletchingOffset
        nockType = arrow.nockType ?? ""
        totalWeightText = arrow.totalWeight.map { String($0) } ?? ""
        shaftDiameter = arrow.shaftDiameter
        notes = arrow.notes ?? ""
    }

    private func save() async {
        isSaving = true
        let updatedArrow = ArrowConfiguration(
            id: arrow.id, userId: arrow.userId,
            label: label.trimmingCharacters(in: .whitespaces),
            brand: brand.isEmpty ? nil : brand.trimmingCharacters(in: .whitespaces),
            model: model.isEmpty ? nil : model.trimmingCharacters(in: .whitespaces),
            length: length, pointWeight: pointWeight,
            fletchingType: fletchingType, fletchingLength: fletchingLength,
            fletchingOffset: fletchingOffset,
            nockType: nockType.isEmpty ? nil : nockType.trimmingCharacters(in: .whitespaces),
            totalWeight: Int(totalWeightText), shaftDiameter: shaftDiameter,
            notes: notes.isEmpty ? nil : notes
        )
        do {
            try store.save(arrowConfig: updatedArrow)
            Task {
                if let _ = try? await APIClient.shared.createArrowConfig(updatedArrow) {
                    try? store.markArrowConfigSynced(id: updatedArrow.id)
                }
            }
            if let idx = appState.arrowConfigs.firstIndex(where: { $0.id == arrow.id }) {
                appState.arrowConfigs[idx] = updatedArrow
            }
            withAnimation { showSavedBanner = true }
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation { showSavedBanner = false }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Preview

#Preview {
    let arrow = ArrowConfiguration(
        id: "a1",
        userId: "u1",
        label: "Match Arrows",
        brand: "Easton",
        model: "X10",
        length: 28.5,
        pointWeight: 110,
        fletchingType: .vane,
        fletchingLength: 2.0,
        fletchingOffset: 1.5,
        nockType: "pin",
        totalWeight: 420,
        notes: "Used for indoor 18m competition. Replace point after 300 shots."
    )
    let appState = AppState()
    appState.arrowConfigs = [arrow]
    return NavigationStack {
        ArrowDetailView(arrow: arrow, appState: appState)
    }
}
