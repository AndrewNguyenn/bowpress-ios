import SwiftUI

struct AddBowView: View {
    var appState: AppState

    @Environment(\.dismiss) private var dismiss
    private let catalog = BowCatalogLoader.shared

    @State private var selectedManufacturer: CatalogManufacturer?
    @State private var selectedModel: CatalogModel?
    @State private var selectedColor: CatalogColor?
    @State private var isOtherSelected = false
    @State private var otherBrand = ""
    @State private var otherModel = ""
    @State private var customName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var readyForName: Bool {
        isOtherSelected || selectedColor != nil
    }

    private var canSave: Bool {
        guard !customName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return isOtherSelected || (selectedModel != nil && selectedColor != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Manufacturer") {
                    ForEach(catalog.manufacturers) { mfr in
                        catalogRow(mfr.name, isSelected: selectedManufacturer?.id == mfr.id) {
                            selectedManufacturer = mfr
                            selectedModel = nil
                            selectedColor = nil
                            isOtherSelected = false
                        }
                    }
                    catalogRow("Other", isSelected: isOtherSelected) {
                        isOtherSelected = true
                        selectedManufacturer = nil
                        selectedModel = nil
                        selectedColor = nil
                    }
                }

                if isOtherSelected {
                    Section("Details") {
                        LabeledContent("Brand") {
                            TextField("Optional", text: $otherBrand)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Model") {
                            TextField("Optional", text: $otherModel)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                if let mfr = selectedManufacturer {
                    Section("Model") {
                        ForEach(mfr.models) { model in
                            catalogRow(model.name, isSelected: selectedModel?.id == model.id) {
                                selectedModel = model
                                selectedColor = nil
                            }
                        }
                    }
                }

                if let model = selectedModel {
                    Section("Color") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                            ForEach(model.colors) { color in
                                ColorSwatch(color: color, isSelected: selectedColor?.id == color.id) {
                                    selectedColor = color
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                        if let selected = selectedColor {
                            Text(selected.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                }

                if readyForName {
                    Section("Name Your Bow") {
                        TextField("e.g. My Mathews, Competition Rig", text: $customName)
                    }
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

    @ViewBuilder
    private func catalogRow(_ name: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        HStack {
            Text(name)
                .font(.body.weight(isSelected ? .semibold : .regular))
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.appAccent)
                    .font(.caption.weight(.semibold))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        let brand = isOtherSelected ? otherBrand.trimmingCharacters(in: .whitespaces) : (selectedManufacturer?.name ?? "")
        let model = isOtherSelected ? otherModel.trimmingCharacters(in: .whitespaces) : (selectedModel?.name ?? "")
        let newBow = Bow(
            id: UUID().uuidString,
            userId: appState.currentUser?.id ?? "",
            name: customName.trimmingCharacters(in: .whitespaces),
            brand: brand,
            model: model,
            createdAt: Date()
        )
        do {
            let created = try await APIClient.shared.createBow(newBow)
            appState.bows.append(created)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Supporting views

private struct ColorSwatch: View {
    let color: CatalogColor
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(color.swatchColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: isSelected ? 3 : 1)
                    )
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(color.swatchColor.luminance > 0.6 ? Color.black : Color.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// Luminance helper for checkmark contrast
extension Color {
    var luminance: Double {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        return 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
    }
}

// MARK: - Add Arrow (companion)

struct AddArrowView: View {
    var appState: AppState

    @Environment(\.dismiss) private var dismiss

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

    private var canSave: Bool { !label.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
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
                Section("Specs") {
                    Stepper(value: $length, in: 18.0...36.0, step: 0.25) {
                        LabeledContent("Length", value: "\(String(format: "%.2f", length))\"")
                    }
                    Stepper(value: $pointWeight, in: 50...200, step: 5) {
                        LabeledContent("Point Weight", value: "\(pointWeight) gr")
                    }
                }
                Section("Fletching") {
                    Picker("Type", selection: $fletchingType) {
                        ForEach(ArrowConfiguration.FletchingType.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag($0)
                        }
                    }
                    Stepper(value: $fletchingLength, in: 1.0...5.0, step: 0.25) {
                        LabeledContent("Length", value: "\(String(format: "%.2f", fletchingLength))\"")
                    }
                    Stepper(value: $fletchingOffset, in: 0.0...10.0, step: 0.5) {
                        LabeledContent("Offset", value: "\(String(format: "%.1f", fletchingOffset))°")
                    }
                }
                Section("Shaft Diameter") {
                    Picker("Diameter", selection: $shaftDiameter) {
                        Text("Not set").tag(ArrowConfiguration.ShaftDiameter?.none)
                        ForEach(ArrowConfiguration.ShaftDiameter.allCases, id: \.self) { d in
                            Text(d.displayName).tag(ArrowConfiguration.ShaftDiameter?.some(d))
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
            let created = try await APIClient.shared.createArrowConfig(newArrow)
            appState.arrowConfigs.append(created)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
        isSaving = false
    }
}

// MARK: - Previews

#Preview("Add Bow") { AddBowView(appState: AppState()) }
#Preview("Add Arrow") { AddArrowView(appState: AppState()) }
