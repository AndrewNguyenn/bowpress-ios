import SwiftUI

struct SessionConfigSheet: View {
    var appState: AppState
    @Bindable var viewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    // Local edit state
    @State private var editingBowConfig: Bool = false
    @State private var draftBowConfig: BowConfiguration?
    @State private var selectedArrowConfig: ArrowConfiguration?

    private var activeBowConfig: BowConfiguration? { viewModel.pendingBowConfig ?? viewModel.activeBowConfig }
    private var activeArrowConfig: ArrowConfiguration? { viewModel.pendingArrowConfig ?? viewModel.activeArrowConfig }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: Config-change notice
                    changeNotice

                    // MARK: Current bow config
                    if editingBowConfig {
                        BowConfigEditForm(
                            config: draftBowConfig ?? activeBowConfig ?? .makeDefault(for: viewModel.selectedBow?.id ?? ""),
                            onChange: { draftBowConfig = $0 }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        bowConfigSummarySection
                    }

                    // MARK: Arrow config picker
                    arrowConfigSection

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .animation(.easeInOut(duration: 0.22), value: editingBowConfig)
            }
            .navigationTitle("Change Config")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { applyAndDismiss() }
                        .fontWeight(.semibold)
                        .disabled(!hasChanges)
                }
            }
            .onAppear {
                selectedArrowConfig = activeArrowConfig
            }
        }
    }

    // MARK: - Sub-views

    private var changeNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 16))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("Notes will clear.")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("A new session segment starts with your next arrow.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private var bowConfigSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Bow Configuration", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
                Button {
                    draftBowConfig = activeBowConfig
                    withAnimation { editingBowConfig = true }
                } label: {
                    Text("Edit")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.accentColor)
                }
            }

            if let config = activeBowConfig {
                BowConfigFullSummary(config: config)
            } else {
                Text("No configuration active.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var arrowConfigSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Arrow Configuration", systemImage: "arrow.right")
                .font(.headline)

            if appState.arrowConfigs.isEmpty {
                Text("No arrow configs available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(appState.arrowConfigs) { arrow in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedArrowConfig = arrow
                            }
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(arrow.label)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text(arrowDetail(arrow))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedArrowConfig?.id == arrow.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if arrow.id != appState.arrowConfigs.last?.id {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.separator, lineWidth: 0.5)
                )
            }
        }
    }

    // MARK: - Logic

    private var hasChanges: Bool {
        let bowChanged = draftBowConfig != nil && draftBowConfig?.id != activeBowConfig?.id
            || (draftBowConfig != nil && draftBowConfig != activeBowConfig)
        let arrowChanged = selectedArrowConfig?.id != activeArrowConfig?.id
        return bowChanged || arrowChanged
    }

    private func applyAndDismiss() {
        let newArrow = selectedArrowConfig?.id != activeArrowConfig?.id ? selectedArrowConfig : nil
        let newBow: BowConfiguration?

        if editingBowConfig, let draft = draftBowConfig {
            // Assign a fresh ID to signal it's a new config snapshot
            var saved = draft
            if saved == activeBowConfig {
                newBow = nil
            } else {
                saved.id = UUID().uuidString
                saved.createdAt = Date()
                newBow = saved
            }
        } else {
            newBow = nil
        }

        if newBow != nil || newArrow != nil {
            viewModel.applyConfigChange(bowConfig: newBow, arrowConfig: newArrow)
        }
        dismiss()
    }

    private func arrowDetail(_ arrow: ArrowConfiguration) -> String {
        [String(format: "%.2f\"", arrow.length), "\(arrow.pointWeight)gr", arrow.fletchingType.rawValue]
            .joined(separator: " · ")
    }
}

// MARK: - Bow Config Full Summary

private struct BowConfigFullSummary: View {
    var config: BowConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            configGroup("Draw & Let-Off", items: [
                ("Draw Length", String(format: "%.1f\"", config.drawLength)),
                ("Let-Off",     String(format: "%.0f%%", config.letOffPct)),
            ])
            Divider().padding(.leading, 14)
            configGroup("String & Cable", items: [
                ("Peep Height",           String(format: "%.2f\"", config.peepHeight)),
                ("D-Loop",                String(format: "%.2f\"", config.dLoopLength)),
                ("Top Cable Twists",      "\(config.topCableTwists)"),
                ("Bottom Cable Twists",   "\(config.bottomCableTwists)"),
                ("String Top Twists",     "\(config.mainStringTopTwists)"),
                ("String Bottom Twists",  "\(config.mainStringBottomTwists)"),
            ])
            Divider().padding(.leading, 14)
            configGroup("Limbs", items: [
                ("Top Limb Turns",    String(format: "%.1f", config.topLimbTurns)),
                ("Bottom Limb Turns", String(format: "%.1f", config.bottomLimbTurns)),
            ])
            Divider().padding(.leading, 14)
            configGroup("Rest", items: [
                ("Vertical",   "\(config.restVertical >= 0 ? "+" : "")\(config.restVertical)/16\""),
                ("Horizontal", "\(config.restHorizontal >= 0 ? "+" : "")\(config.restHorizontal)/16\""),
                ("Depth",      String(format: "%.2f\"", config.restDepth)),
            ])
            Divider().padding(.leading, 14)
            configGroup("Sight / Grip / Nock", items: [
                ("Sight Position", config.sightPosition == 0 ? "0 (baseline)" : "\(config.sightPosition > 0 ? "+" : "")\(config.sightPosition)"),
                ("Grip Angle",     String(format: "%.1f°", config.gripAngle)),
                ("Nocking Height", "\(config.nockingHeight >= 0 ? "+" : "")\(config.nockingHeight)/16\""),
            ])
            Divider().padding(.leading, 14)
            configGroup("Front Stabilizer", items: [
                ("Weight", config.frontStabWeight == 0 ? "None" : "\(String(format: "%g", config.frontStabWeight)) oz"),
                ("Angle",  "\(Int(config.frontStabAngle))°"),
            ])
            Divider().padding(.leading, 14)
            configGroup("Rear Stabilizer", items: config.rearStabSide == .none
                ? [("Side", "None")]
                : [
                    ("Side",             config.rearStabSide.label),
                    ("Weight",           "\(String(format: "%g", config.rearStabWeight)) oz"),
                    ("Vertical Angle",   "\(Int(config.rearStabVertAngle))°"),
                    ("Horizontal Angle", "\(Int(config.rearStabHorizAngle))°"),
                ]
            )
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func configGroup(_ title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 4)

            ForEach(items, id: \.0) { label, value in
                HStack {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
            }
        }
    }
}

// MARK: - Bow Config Edit Form

private struct BowConfigEditForm: View {
    var config: BowConfiguration
    var onChange: (BowConfiguration) -> Void

    @State private var draft: BowConfiguration

    init(config: BowConfiguration, onChange: @escaping (BowConfiguration) -> Void) {
        self.config = config
        self.onChange = onChange
        self._draft = State(initialValue: config)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Edit Bow Parameters", systemImage: "pencil")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 0) {
                // Draw / Let-Off
                editSection("Draw & Let-Off") {
                    doubleField("Draw Length (in)", value: $draft.drawLength, format: "%.1f")
                    Divider().padding(.leading, 14)
                    doubleField("Let-Off (%)", value: $draft.letOffPct, format: "%.0f")
                }

                Divider().padding(.leading, 14)

                // String & Cable
                editSection("String & Cable") {
                    doubleField("Peep Height (in)", value: $draft.peepHeight, format: "%.2f")
                    Divider().padding(.leading, 14)
                    doubleField("D-Loop (in)", value: $draft.dLoopLength, format: "%.2f")
                    Divider().padding(.leading, 14)
                    intField("Top Cable Twists", value: $draft.topCableTwists)
                    Divider().padding(.leading, 14)
                    intField("Bottom Cable Twists", value: $draft.bottomCableTwists)
                    Divider().padding(.leading, 14)
                    intField("String Top Twists", value: $draft.mainStringTopTwists)
                    Divider().padding(.leading, 14)
                    intField("String Bottom Twists", value: $draft.mainStringBottomTwists)
                }

                Divider().padding(.leading, 14)

                // Limbs
                editSection("Limbs") {
                    doubleField("Top Limb Turns", value: $draft.topLimbTurns, format: "%.1f")
                    Divider().padding(.leading, 14)
                    doubleField("Bottom Limb Turns", value: $draft.bottomLimbTurns, format: "%.1f")
                }

                Divider().padding(.leading, 14)

                // Rest
                editSection("Rest") {
                    intField("Vertical (1/16 in)", value: $draft.restVertical)
                    Divider().padding(.leading, 14)
                    intField("Horizontal (1/16 in)", value: $draft.restHorizontal)
                    Divider().padding(.leading, 14)
                    doubleField("Depth (in)", value: $draft.restDepth, format: "%.2f")
                }

                Divider().padding(.leading, 14)

                // Sight / Grip / Nock
                editSection("Sight / Grip / Nock") {
                    intField("Sight Position", value: $draft.sightPosition)
                    Divider().padding(.leading, 14)
                    doubleField("Grip Angle (°)", value: $draft.gripAngle, format: "%.1f")
                    Divider().padding(.leading, 14)
                    intField("Nocking Height (1/16 in)", value: $draft.nockingHeight)
                }

                Divider().padding(.leading, 14)

                editSection("Front Stabilizer") {
                    doubleField("Weight (oz)", value: $draft.frontStabWeight, format: "%.1f")
                    Divider().padding(.leading, 14)
                    doubleField("Angle (°)", value: $draft.frontStabAngle, format: "%.0f")
                }

                Divider().padding(.leading, 14)

                editSection("Rear Stabilizer") {
                    HStack {
                        Text("Side")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: $draft.rearStabSide) {
                            ForEach(RearStabSide.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    if draft.rearStabSide != .none {
                        Divider().padding(.leading, 14)
                        doubleField("Weight (oz)", value: $draft.rearStabWeight, format: "%.1f")
                        Divider().padding(.leading, 14)
                        doubleField("Vertical Angle (°)", value: $draft.rearStabVertAngle, format: "%.0f")
                        Divider().padding(.leading, 14)
                        doubleField("Horizontal Angle (°)", value: $draft.rearStabHorizAngle, format: "%.0f")
                    }
                }
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )
        }
        .onChange(of: draft) { _, new in onChange(new) }
    }

    @ViewBuilder
    private func editSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 4)
            content()
        }
    }

    @ViewBuilder
    private func doubleField(_ label: String, value: Binding<Double>, format: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            TextField("", value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 80)
                .keyboardType(.decimalPad)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func intField(_ label: String, value: Binding<Int>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            TextField("", value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 60)
                .keyboardType(.numberPad)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Preview

#Preview {
    let appState = AppState()
    appState.arrowConfigs = [
        ArrowConfiguration(
            id: "a1", userId: "u1", label: "Match Arrows",
            brand: "Easton", model: "X10",
            length: 28.5, pointWeight: 110,
            fletchingType: .vane, fletchingLength: 2.0, fletchingOffset: 1.5
        ),
        ArrowConfiguration(
            id: "a2", userId: "u1", label: "Practice",
            brand: "Gold Tip", model: "Hunter XT",
            length: 29.0, pointWeight: 100,
            fletchingType: .vane, fletchingLength: 2.25, fletchingOffset: 2.0
        )
    ]
    let vm = SessionViewModel()
    vm.activeBowConfig = BowConfiguration.makeDefault(for: "b1")
    vm.activeArrowConfig = appState.arrowConfigs.first
    vm.isSessionActive = true

    return SessionConfigSheet(appState: appState, viewModel: vm)
}
