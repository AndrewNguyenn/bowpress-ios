import SwiftUI

struct AddBowView: View {
    var appState: AppState
    var onCreated: (Bow) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(LocalStore.self) private var store

    @State private var bowType: BowType = .compound
    @State private var customName: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !customName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bow Type") {
                    Picker("Type", selection: $bowType) {
                        ForEach(BowType.allCases, id: \.self) {
                            Text($0.label).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Name Your Bow") {
                    TextField("e.g. My Hoyt, Competition Rig", text: $customName)
                        .accessibilityIdentifier("bow_name_field")
                }
            }
            .navigationTitle("Add Bow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .disabled(!canSave)
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
        }
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        let newBow = Bow(
            id: UUID().uuidString,
            userId: appState.currentUser?.id ?? "",
            name: customName.trimmingCharacters(in: .whitespaces),
            bowType: bowType,
            brand: "",
            model: "",
            createdAt: Date()
        )
        do {
            try store.save(bow: newBow)
            appState.bows.append(newBow)

            // Spec "Data Flow Summary": a new Bow always gets a v1 BowConfiguration
            // so analysis has something to anchor to. Without this, sessions starting
            // immediately after bow creation fall back to an in-memory compound
            // default that never persists — which caused the "can't start session"
            // symptom for newly-added recurve bows.
            let initialConfig = BowConfiguration.makeDefault(for: newBow)
            try store.save(config: initialConfig)
            appState.bowConfigs[newBow.id] = initialConfig

            Task {
                if let _ = try? await APIClient.shared.createBow(newBow) {
                    try? store.markBowSynced(id: newBow.id)
                }
                if let _ = try? await APIClient.shared.createConfiguration(initialConfig) {
                    try? store.markBowConfigSynced(id: initialConfig.id)
                }
            }
            onCreated(newBow)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Add Arrow (companion)

struct AddArrowView: View {
    var appState: AppState

    @Environment(\.dismiss) private var dismiss
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
    @State private var shaftDiameter: ArrowConfiguration.ShaftDiameter? = nil
    @State private var isSaving = false
    @State private var errorMessage: String?
    @AppStorage(UnitSystem.storageKey) private var unitSystem: UnitSystem = .imperial

    private var canSave: Bool { !label.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section { UnitToggle(system: $unitSystem) }

                Section("Identity") {
                    LabeledContent("Label") {
                        TextField("Required", text: $label)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("arrow_label_field")
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
                Section("Specs") {
                    Stepper(
                        value: $length.displayed(in: unitSystem, scale: .inchToCm),
                        in: UnitRange.arrowLength.displayRange(unitSystem),
                        step: UnitRange.arrowLength.displayStep(unitSystem)
                    ) {
                        LabeledContent("Length",
                                       value: UnitFormatting.length(inches: length, system: unitSystem))
                    }
                    Stepper(
                        value: $pointWeight.displayed(in: unitSystem, scale: .grainToGram),
                        in: UnitRange.pointWeight.displayRange(unitSystem),
                        step: UnitRange.pointWeight.displayStep(unitSystem)
                    ) {
                        LabeledContent("Point Weight",
                                       value: UnitFormatting.arrowMass(grains: pointWeight, system: unitSystem))
                    }
                }
                Section("Fletching") {
                    Picker("Type", selection: $fletchingType) {
                        ForEach(ArrowConfiguration.FletchingType.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag($0)
                        }
                    }
                    Stepper(
                        value: $fletchingLength.displayed(in: unitSystem, scale: .inchToCm),
                        in: UnitRange.fletchingLength.displayRange(unitSystem),
                        step: UnitRange.fletchingLength.displayStep(unitSystem)
                    ) {
                        LabeledContent("Length",
                                       value: UnitFormatting.length(inches: fletchingLength, system: unitSystem))
                    }
                    Stepper(value: $fletchingOffset, in: 0.0...10.0, step: 0.5) {
                        LabeledContent("Offset", value: UnitFormatting.degrees(fletchingOffset))
                    }
                }
                Section("Shaft Diameter") {
                    Picker("Diameter", selection: $shaftDiameter) {
                        Text("Not set").tag(ArrowConfiguration.ShaftDiameter?.none)
                        ForEach(ArrowConfiguration.ShaftDiameter.allCases, id: \.self) { d in
                            Text(d.displayName(for: unitSystem)).tag(ArrowConfiguration.ShaftDiameter?.some(d))
                        }
                    }
                    .pickerStyle(.wheel)
                }
                Section("Nock") {
                    LabeledContent("Nock Type") {
                        TextField("Optional", text: $nockType)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Add Arrow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving { ProgressView() }
                    else { Button("Save") { Task { await save() } }.disabled(!canSave) }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        let newArrow = ArrowConfiguration(
            id: UUID().uuidString,
            userId: appState.currentUser?.id ?? "",
            label: label.trimmingCharacters(in: .whitespaces),
            brand: brand.isEmpty ? nil : brand,
            model: model.isEmpty ? nil : model,
            length: length, pointWeight: pointWeight,
            fletchingType: fletchingType,
            fletchingLength: fletchingLength,
            fletchingOffset: fletchingOffset,
            nockType: nockType.isEmpty ? nil : nockType,
            totalWeight: nil,
            shaftDiameter: shaftDiameter,
            notes: nil
        )
        do {
            try store.save(arrowConfig: newArrow)
            appState.arrowConfigs.append(newArrow)
            Task {
                if let _ = try? await APIClient.shared.createArrowConfig(newArrow) {
                    try? store.markArrowConfigSynced(id: newArrow.id)
                }
            }
            dismiss()
        } catch { errorMessage = error.localizedDescription }
        isSaving = false
    }
}

// MARK: - Previews

#Preview("Add Bow") { AddBowView(appState: AppState()) }
#Preview("Add Arrow") { AddArrowView(appState: AppState()) }
