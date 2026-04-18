import SwiftUI

struct SessionConfigSheet: View {
    var appState: AppState
    @Bindable var viewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    // Individual state fields — mirrors BowConfigEditView
    @State private var drawLength: Double = 28.0
    @State private var letOffPct: Double = 80
    @State private var peepHeight: Double = 9.0
    @State private var dLoopLength: Double = 2.0
    @State private var dLoopText: String = "2.0"
    @State private var topCableTwists: Int = 0
    @State private var bottomCableTwists: Int = 0
    @State private var mainStringTopTwists: Int = 0
    @State private var mainStringBottomTwists: Int = 0
    @State private var topLimbTurns: Double = 0
    @State private var bottomLimbTurns: Double = 0
    @State private var restVertical: Int = 0
    @State private var restHorizontal: Int = 0
    @State private var restDepth: Double = 0
    @State private var sightPosition: Int = 0
    @State private var gripAngle: Double = 0
    @State private var nockingHeight: Int = 0
    @State private var frontStabWeight: Double = 0
    @State private var frontStabAngle: Double = 0
    @State private var rearStabSide: RearStabSide = .none
    @State private var rearStabWeight: Double = 0
    @State private var rearStabVertAngle: Double = 0
    @State private var rearStabHorizAngle: Double = 0

    @State private var selectedArrowConfig: ArrowConfiguration? = nil
    @State private var baselineConfig: BowConfiguration = .makeDefault(for: "")
    @State private var baselineArrowId: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.hasPendingConfigChange {
                    Section {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Change pending — waiting for next shot")
                                    .font(.subheadline).fontWeight(.semibold)
                                Text("Takes effect when you fire your next arrow.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if appState.arrowConfigs.count > 1 {
                    Section("Arrow") {
                        ForEach(appState.arrowConfigs) { arrow in
                            ArrowPickerRow(
                                arrow: arrow,
                                detail: arrowDetail(arrow),
                                isSelected: selectedArrowConfig?.id == arrow.id,
                                onTap: { selectedArrowConfig = arrow }
                            )
                        }
                    }
                }

                Section("Draw & Setup") {
                    drawLengthRow
                    Stepper(value: $letOffPct, in: 40...99, step: 1) {
                        LabeledContent("Let-off", value: "\(Int(letOffPct))%")
                    }
                    peepHeightRow
                    LabeledContent("D-Loop Length") {
                        HStack(spacing: 8) {
                            Button {
                                dLoopLength = max(0.1, (dLoopLength * 16 - 1) / 16)
                                dLoopText = String(format: "%g", dLoopLength)
                            } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain).foregroundStyle(Color.appAccent)
                            HStack(spacing: 2) {
                                TextField("in", text: $dLoopText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 60)
                                    .onChange(of: dLoopText) { _, val in
                                        if let v = Double(val) { dLoopLength = v }
                                    }
                                Text("\"").foregroundStyle(.secondary)
                            }
                            Button {
                                dLoopLength = min(5.0, (dLoopLength * 16 + 1) / 16)
                                dLoopText = String(format: "%g", dLoopLength)
                            } label: { Image(systemName: "plus.circle") }
                            .buttonStyle(.plain).foregroundStyle(Color.appAccent)
                        }
                    }
                }

                Section("String & Cable") {
                    Stepper(value: $topCableTwists, in: -10...10) {
                        LabeledContent("Top Cable", value: halfTwistLabel(topCableTwists))
                    }
                    Stepper(value: $bottomCableTwists, in: -10...10) {
                        LabeledContent("Bottom Cable", value: halfTwistLabel(bottomCableTwists))
                    }
                    Stepper(value: $mainStringTopTwists, in: -10...10) {
                        LabeledContent("Main String Top", value: halfTwistLabel(mainStringTopTwists))
                    }
                    Stepper(value: $mainStringBottomTwists, in: -10...10) {
                        LabeledContent("Main String Bottom", value: halfTwistLabel(mainStringBottomTwists))
                    }
                }

                Section("Limbs") {
                    Stepper(value: $topLimbTurns, in: -10.0...10.0, step: 0.5) {
                        LabeledContent("Top Limb", value: limbTurnsLabel(topLimbTurns))
                    }
                    Stepper(value: $bottomLimbTurns, in: -10.0...10.0, step: 0.5) {
                        LabeledContent("Bottom Limb", value: limbTurnsLabel(bottomLimbTurns))
                    }
                }

                Section("Rest") {
                    Stepper(value: $restVertical, in: -16...16) {
                        LabeledContent("Vertical", value: sixteenthLabel(restVertical))
                    }
                    Stepper(value: $restHorizontal, in: -16...16) {
                        LabeledContent("Horizontal", value: sixteenthLabel(restHorizontal))
                    }
                    Stepper(value: $restDepth, in: -5.0...5.0, step: 0.25) {
                        LabeledContent("Depth", value: "\(String(format: "%.2f", restDepth))\"")
                    }
                }

                Section("Sight, Grip & Nock") {
                    Stepper(value: $sightPosition, in: -15...15) {
                        LabeledContent("Sight Position", value: sightPosition == 0 ? "0 (baseline)" : "\(sightPosition > 0 ? "+" : "")\(sightPosition)")
                    }
                    Stepper(value: $gripAngle, in: 0.0...90.0, step: 0.5) {
                        LabeledContent("Grip Angle", value: "\(String(format: "%.1f", gripAngle))°")
                    }
                    Stepper(value: $nockingHeight, in: -80...80) {
                        LabeledContent("Nocking Height", value: sixteenthLabel(nockingHeight))
                    }
                }

                Section("Front Stabilizer") {
                    Stepper(value: $frontStabWeight, in: 0...60, step: 0.5) {
                        LabeledContent("Weight", value: frontStabWeight == 0 ? "None" : "\(String(format: "%g", frontStabWeight)) oz")
                    }
                    Stepper(value: $frontStabAngle, in: 0...10, step: 1) {
                        LabeledContent("Angle", value: "\(Int(frontStabAngle))°")
                    }
                }

                Section("Rear Stabilizer") {
                    Picker("Side", selection: $rearStabSide) {
                        ForEach(RearStabSide.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    if rearStabSide != .none {
                        Stepper(value: $rearStabWeight, in: 0...60, step: 0.5) {
                            LabeledContent("Weight", value: "\(String(format: "%g", rearStabWeight)) oz")
                        }
                        Stepper(value: $rearStabVertAngle, in: -90...90, step: 5) {
                            LabeledContent("Vertical Angle", value: "\(Int(rearStabVertAngle))°")
                        }
                        Stepper(value: $rearStabHorizAngle, in: 0...90, step: 5) {
                            LabeledContent("Horizontal Angle", value: "\(Int(rearStabHorizAngle))°")
                        }
                    }
                }
            }
            .navigationTitle("Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { seedFromActive() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { applyAndDismiss() }
                        .fontWeight(.semibold)
                        .disabled(!hasChanges)
                }
            }
        }
    }

    // MARK: - Seeding

    private func seedFromActive() {
        let config = viewModel.pendingBowConfig ?? viewModel.activeBowConfig
            ?? .makeDefault(for: viewModel.selectedBow?.id ?? "")
        baselineConfig = config
        drawLength = config.drawLength
        letOffPct = config.letOffPct
        peepHeight = config.peepHeight
        dLoopLength = config.dLoopLength
        dLoopText = String(format: "%g", config.dLoopLength)
        topCableTwists = config.topCableTwists
        bottomCableTwists = config.bottomCableTwists
        mainStringTopTwists = config.mainStringTopTwists
        mainStringBottomTwists = config.mainStringBottomTwists
        topLimbTurns = config.topLimbTurns
        bottomLimbTurns = config.bottomLimbTurns
        restVertical = config.restVertical
        restHorizontal = config.restHorizontal
        restDepth = config.restDepth
        sightPosition = config.sightPosition
        gripAngle = config.gripAngle
        nockingHeight = config.nockingHeight
        frontStabWeight = config.frontStabWeight
        frontStabAngle = config.frontStabAngle
        rearStabSide = config.rearStabSide
        rearStabWeight = config.rearStabWeight
        rearStabVertAngle = config.rearStabVertAngle
        rearStabHorizAngle = config.rearStabHorizAngle
        let arrow = viewModel.pendingArrowConfig ?? viewModel.activeArrowConfig
        selectedArrowConfig = arrow
        baselineArrowId = arrow?.id
    }

    // MARK: - Logic

    private var currentDraft: BowConfiguration {
        BowConfiguration(
            id: baselineConfig.id, bowId: baselineConfig.bowId,
            createdAt: baselineConfig.createdAt, label: baselineConfig.label,
            drawLength: drawLength, letOffPct: letOffPct,
            peepHeight: peepHeight, dLoopLength: dLoopLength,
            topCableTwists: topCableTwists, bottomCableTwists: bottomCableTwists,
            mainStringTopTwists: mainStringTopTwists, mainStringBottomTwists: mainStringBottomTwists,
            topLimbTurns: topLimbTurns, bottomLimbTurns: bottomLimbTurns,
            restVertical: restVertical, restHorizontal: restHorizontal, restDepth: restDepth,
            sightPosition: sightPosition, gripAngle: gripAngle, nockingHeight: nockingHeight,
            frontStabWeight: frontStabWeight, frontStabAngle: frontStabAngle,
            rearStabSide: rearStabSide, rearStabWeight: rearStabWeight,
            rearStabVertAngle: rearStabVertAngle, rearStabHorizAngle: rearStabHorizAngle
        )
    }

    private var hasChanges: Bool {
        currentDraft != baselineConfig || selectedArrowConfig?.id != baselineArrowId
    }

    private func applyAndDismiss() {
        let draft = currentDraft
        let newBow: BowConfiguration?
        if draft == baselineConfig {
            newBow = nil
        } else {
            var saved = draft
            saved.id = UUID().uuidString
            saved.createdAt = Date()
            newBow = saved
        }
        let newArrow = selectedArrowConfig?.id != baselineArrowId ? selectedArrowConfig : nil
        if newBow != nil || newArrow != nil {
            viewModel.applyConfigChange(bowConfig: newBow, arrowConfig: newArrow)
        }
        dismiss()
    }

    private func arrowDetail(_ arrow: ArrowConfiguration) -> String {
        [String(format: "%.2f\"", arrow.length), "\(arrow.pointWeight)gr", arrow.fletchingType.rawValue]
            .joined(separator: " · ")
    }

    // MARK: - Input rows

    private var drawLengthRow: some View {
        LabeledContent("Draw Length") {
            HStack(spacing: 8) {
                Button {
                    drawLength = max(17.0, (drawLength * 4 - 1) / 4)
                } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.plain).foregroundStyle(Color.appAccent)
                HStack(spacing: 2) {
                    TextField("in", text: Binding(
                        get: { String(format: "%g", drawLength) },
                        set: { if let v = Double($0) { drawLength = v } }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 60)
                    Text("\"").foregroundStyle(.secondary)
                }
                Button {
                    drawLength = min(37.0, (drawLength * 4 + 1) / 4)
                } label: { Image(systemName: "plus.circle") }
                .buttonStyle(.plain).foregroundStyle(Color.appAccent)
            }
        }
    }

    private var peepHeightRow: some View {
        LabeledContent("Peep Height") {
            HStack(spacing: 8) {
                Button {
                    peepHeight = max(3.0, (peepHeight * 10 - 1) / 10)
                } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.plain).foregroundStyle(Color.appAccent)
                HStack(spacing: 2) {
                    TextField("in", text: Binding(
                        get: { String(format: "%g", peepHeight) },
                        set: { if let v = Double($0) { peepHeight = v } }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 60)
                    Text("\"").foregroundStyle(.secondary)
                }
                Button {
                    peepHeight = min(17.0, (peepHeight * 10 + 1) / 10)
                } label: { Image(systemName: "plus.circle") }
                .buttonStyle(.plain).foregroundStyle(Color.appAccent)
            }
        }
    }

    // MARK: - Formatters

    private func halfTwistLabel(_ n: Int) -> String {
        if n == 0 { return "0 twists" }
        let twists = Double(n) / 2.0
        let formatted = twists == twists.rounded() ? String(format: "%.0f", twists) : String(format: "%g", twists)
        return "\(n > 0 ? "+" : "")\(formatted) twist\(abs(twists) == 1 ? "" : "s")"
    }

    private func limbTurnsLabel(_ turns: Double) -> String {
        if turns == 0 { return "0 turns" }
        let absVal = abs(turns)
        let direction = turns < 0 ? "out" : "in"
        let formatted = absVal == absVal.rounded() ? String(format: "%.0f", absVal) : String(format: "%.1f", absVal)
        return "\(formatted) turn\(absVal == 1 ? "" : "s") \(direction)"
    }

    private func sixteenthLabel(_ n: Int) -> String {
        if n == 0 { return "0/16\"" }
        return "\(n > 0 ? "+" : "-")\(abs(n))/16\""
    }
}

// MARK: - ArrowPickerRow

private struct ArrowPickerRow: View {
    let arrow: ArrowConfiguration
    let detail: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(arrow.label).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(Color.appAccent)
                }
            }
        }
        .buttonStyle(.plain)
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
