import SwiftUI

struct SessionConfigSheet: View {
    var appState: AppState
    @Bindable var viewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UnitSystem.storageKey) private var unitSystem: UnitSystem = .imperial

    // Shared
    @State private var drawLength: Double = 28.0
    @State private var restVertical: Int = 0
    @State private var restHorizontal: Int = 0
    @State private var restDepth: Double = 0
    @State private var sightPosition: Int = 0
    @State private var gripAngle: Double = 0
    @State private var nockingHeight: Int = 0

    // Compound
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
    @State private var frontStabWeight: Double = 0
    @State private var frontStabAngle: Double = 0
    @State private var rearStabSide: RearStabSide = .none
    @State private var rearStabWeight: Double = 0
    @State private var rearStabVertAngle: Double = 0
    @State private var rearStabHorizAngle: Double = 0

    // Recurve / barebow
    @State private var braceHeight: Double = 8.5
    @State private var braceHeightText: String = "8.5"
    @State private var tillerTop: Double = 0
    @State private var tillerBottom: Double = 0
    @State private var plungerTension: Int = 12
    @State private var clickerPosition: Double = 0
    @State private var rearStabLeftWeight: Double = 6
    @State private var rearStabRightWeight: Double = 6

    @State private var selectedArrowConfig: ArrowConfiguration? = nil
    @State private var baselineConfig: BowConfiguration = .makeDefault(for: "")
    @State private var baselineArrowId: String? = nil

    private var bowType: BowType {
        viewModel.selectedBow?.bowType ?? .compound
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { UnitToggle(system: $unitSystem) }

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

                if !appState.arrowConfigs.isEmpty {
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

                switch bowType {
                case .compound: compoundSections
                case .recurve:  recurveSections
                case .barebow:  barebowSections
                }
            }
            .navigationTitle("Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { seedFromActive() }
            .onChange(of: unitSystem) { _, new in
                dLoopText       = UnitFormatting.lengthValue(inches: dLoopLength,  system: new, digits: 3)
                braceHeightText = UnitFormatting.lengthValue(inches: braceHeight, system: new, digits: 3)
            }
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

    // MARK: - Compound form

    @ViewBuilder
    private var compoundSections: some View {
        Section("Draw & Setup") {
            drawLengthRow
            Stepper(value: $letOffPct, in: 40...99, step: 1) {
                LabeledContent("Let-off", value: UnitFormatting.percent(letOffPct))
            }
            peepHeightRow
            dLoopLengthRow
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

        restSection

        Section("Sight, Grip & Nock") {
            Stepper(value: $sightPosition, in: -15...15) {
                LabeledContent("Sight Position", value: sightPosition == 0 ? "0 (baseline)" : "\(sightPosition > 0 ? "+" : "")\(sightPosition)")
            }
            Stepper(value: $gripAngle, in: 0.0...90.0, step: 0.5) {
                LabeledContent("Grip Angle", value: UnitFormatting.degrees(gripAngle))
            }
            Stepper(value: $nockingHeight, in: -80...80) {
                LabeledContent("Nocking Height",
                               value: UnitFormatting.sixteenths(nockingHeight, system: unitSystem))
            }
        }

        Section("Front Stabilizer") {
            Stepper(
                value: $frontStabWeight.displayed(in: unitSystem, scale: .ounceToGram),
                in: UnitRange.frontStabWeight.displayRange(unitSystem),
                step: UnitRange.frontStabWeight.displayStep(unitSystem)
            ) {
                LabeledContent("Weight",
                               value: frontStabWeight == 0 ? "None"
                                                           : UnitFormatting.stabWeight(ounces: frontStabWeight, system: unitSystem))
            }
            Stepper(value: $frontStabAngle, in: 0...10, step: 1) {
                LabeledContent("Angle", value: UnitFormatting.degrees(frontStabAngle, digits: 0))
            }
        }

        Section("Rear Stabilizer") {
            Picker("Side", selection: $rearStabSide) {
                ForEach(RearStabSide.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            if rearStabSide != .none {
                Stepper(
                    value: $rearStabWeight.displayed(in: unitSystem, scale: .ounceToGram),
                    in: UnitRange.rearStabWeight.displayRange(unitSystem),
                    step: UnitRange.rearStabWeight.displayStep(unitSystem)
                ) {
                    LabeledContent("Weight",
                                   value: UnitFormatting.stabWeight(ounces: rearStabWeight, system: unitSystem))
                }
                Stepper(value: $rearStabVertAngle, in: -90...90, step: 5) {
                    LabeledContent("Vertical Angle",
                                   value: UnitFormatting.degrees(rearStabVertAngle, digits: 0))
                }
                Stepper(value: $rearStabHorizAngle, in: 0...90, step: 5) {
                    LabeledContent("Horizontal Angle",
                                   value: UnitFormatting.degrees(rearStabHorizAngle, digits: 0))
                }
            }
        }
    }

    // MARK: - Recurve form

    @ViewBuilder
    private var recurveSections: some View {
        Section("Bow Setup") {
            drawLengthRow
            braceHeightRow
        }

        Section("Tiller") {
            Stepper(
                value: $tillerTop.displayed(in: unitSystem, scale: .mmToInch),
                in: UnitRange.tiller.displayRange(unitSystem),
                step: UnitRange.tiller.displayStep(unitSystem)
            ) {
                LabeledContent("Top Tiller",
                               value: UnitFormatting.mmLength(tillerTop, system: unitSystem))
            }
            Stepper(
                value: $tillerBottom.displayed(in: unitSystem, scale: .mmToInch),
                in: UnitRange.tiller.displayRange(unitSystem),
                step: UnitRange.tiller.displayStep(unitSystem)
            ) {
                LabeledContent("Bottom Tiller",
                               value: UnitFormatting.mmLength(tillerBottom, system: unitSystem))
            }
        }

        Section("Plunger") {
            Stepper(value: $plungerTension, in: 0...30) {
                LabeledContent("Tension", value: "\(plungerTension) clicks")
            }
        }

        Section("Clicker") {
            Stepper(
                value: $clickerPosition.displayed(in: unitSystem, scale: .mmToInch),
                in: UnitRange.clicker.displayRange(unitSystem),
                step: UnitRange.clicker.displayStep(unitSystem)
            ) {
                LabeledContent("Position",
                               value: UnitFormatting.mmLength(clickerPosition, system: unitSystem, digits: 0))
            }
        }

        Section("Grip & Nock") {
            Stepper(value: $gripAngle, in: 0.0...90.0, step: 0.5) {
                LabeledContent("Grip Angle", value: UnitFormatting.degrees(gripAngle))
            }
            Stepper(value: $nockingHeight, in: -80...80) {
                LabeledContent("Nocking Height",
                               value: UnitFormatting.sixteenths(nockingHeight, system: unitSystem))
            }
        }

        Section("Front Stabilizer") {
            Stepper(
                value: $frontStabWeight.displayed(in: unitSystem, scale: .ounceToGram),
                in: UnitRange.vbarWeight.displayRange(unitSystem),
                step: UnitRange.vbarWeight.displayStep(unitSystem)
            ) {
                LabeledContent("Weight",
                               value: UnitFormatting.stabWeight(ounces: frontStabWeight, system: unitSystem))
            }
            Stepper(value: $frontStabAngle, in: 0...10, step: 1) {
                LabeledContent("Angle", value: UnitFormatting.degrees(frontStabAngle, digits: 0))
            }
        }

        Section("V-Bar (Rear Stabilizer)") {
            Stepper(
                value: $rearStabLeftWeight.displayed(in: unitSystem, scale: .ounceToGram),
                in: UnitRange.vbarWeight.displayRange(unitSystem),
                step: UnitRange.vbarWeight.displayStep(unitSystem)
            ) {
                LabeledContent("Left Weight",
                               value: UnitFormatting.stabWeight(ounces: rearStabLeftWeight, system: unitSystem))
            }
            Stepper(
                value: $rearStabRightWeight.displayed(in: unitSystem, scale: .ounceToGram),
                in: UnitRange.vbarWeight.displayRange(unitSystem),
                step: UnitRange.vbarWeight.displayStep(unitSystem)
            ) {
                LabeledContent("Right Weight",
                               value: UnitFormatting.stabWeight(ounces: rearStabRightWeight, system: unitSystem))
            }
            Stepper(value: $rearStabVertAngle, in: -90...90, step: 5) {
                LabeledContent("Vertical Angle",
                               value: UnitFormatting.degrees(rearStabVertAngle, digits: 0))
            }
            Stepper(value: $rearStabHorizAngle, in: 0...90, step: 5) {
                LabeledContent("Horizontal Angle",
                               value: UnitFormatting.degrees(rearStabHorizAngle, digits: 0))
            }
        }
    }

    // MARK: - Barebow form

    @ViewBuilder
    private var barebowSections: some View {
        Section("Bow Setup") {
            drawLengthRow
            braceHeightRow
        }

        Section("Tiller") {
            Stepper(
                value: $tillerTop.displayed(in: unitSystem, scale: .mmToInch),
                in: UnitRange.tiller.displayRange(unitSystem),
                step: UnitRange.tiller.displayStep(unitSystem)
            ) {
                LabeledContent("Top Tiller",
                               value: UnitFormatting.mmLength(tillerTop, system: unitSystem))
            }
            Stepper(
                value: $tillerBottom.displayed(in: unitSystem, scale: .mmToInch),
                in: UnitRange.tiller.displayRange(unitSystem),
                step: UnitRange.tiller.displayStep(unitSystem)
            ) {
                LabeledContent("Bottom Tiller",
                               value: UnitFormatting.mmLength(tillerBottom, system: unitSystem))
            }
        }

        Section("Plunger") {
            Stepper(value: $plungerTension, in: 0...30) {
                LabeledContent("Tension", value: "\(plungerTension) clicks")
            }
        }

        Section("Grip & Nock") {
            Stepper(value: $gripAngle, in: 0.0...90.0, step: 0.5) {
                LabeledContent("Grip Angle", value: UnitFormatting.degrees(gripAngle))
            }
            Stepper(value: $nockingHeight, in: -80...80) {
                LabeledContent("Nocking Height",
                               value: UnitFormatting.sixteenths(nockingHeight, system: unitSystem))
            }
        }
    }

    // MARK: - Shared

    @ViewBuilder
    private var restSection: some View {
        Section("Rest") {
            Stepper(value: $restVertical, in: -16...16) {
                LabeledContent("Vertical",
                               value: UnitFormatting.sixteenths(restVertical, system: unitSystem))
            }
            Stepper(value: $restHorizontal, in: -16...16) {
                LabeledContent("Horizontal",
                               value: UnitFormatting.sixteenths(restHorizontal, system: unitSystem))
            }
            Stepper(
                value: $restDepth.displayed(in: unitSystem, scale: .inchToCm),
                in: UnitRange.restDepth.displayRange(unitSystem),
                step: UnitRange.restDepth.displayStep(unitSystem)
            ) {
                LabeledContent("Depth",
                               value: UnitFormatting.length(inches: restDepth, system: unitSystem))
            }
        }
    }

    // MARK: - Seeding

    private func seedFromActive() {
        let bowId = viewModel.selectedBow?.id ?? ""
        // Pending > most-recently-saved (Equipment tab vs. session start) > default
        let liveAppState = appState.bowConfigs[bowId]
        let sessionActive = viewModel.activeBowConfig
        let mostRecent: BowConfiguration? = {
            switch (liveAppState, sessionActive) {
            case (let l?, let s?): return l.createdAt > s.createdAt ? l : s
            default: return liveAppState ?? sessionActive
            }
        }()
        let config = viewModel.pendingBowConfig ?? mostRecent
            ?? (viewModel.selectedBow.map(BowConfiguration.makeDefault(for:))
                ?? .makeDefault(for: bowId))
        baselineConfig = config

        // Shared
        drawLength = config.drawLength
        restVertical = config.restVertical
        restHorizontal = config.restHorizontal
        restDepth = config.restDepth
        sightPosition = config.sightPosition ?? 0
        gripAngle = config.gripAngle
        nockingHeight = config.nockingHeight

        // Compound
        letOffPct = config.letOffPct ?? 80
        peepHeight = config.peepHeight ?? 9.0
        dLoopLength = config.dLoopLength ?? 2.0
        dLoopText = UnitFormatting.lengthValue(inches: dLoopLength, system: unitSystem, digits: 3)
        topCableTwists = config.topCableTwists ?? 0
        bottomCableTwists = config.bottomCableTwists ?? 0
        mainStringTopTwists = config.mainStringTopTwists ?? 0
        mainStringBottomTwists = config.mainStringBottomTwists ?? 0
        topLimbTurns = config.topLimbTurns ?? 0
        bottomLimbTurns = config.bottomLimbTurns ?? 0
        frontStabWeight = config.frontStabWeight ?? 0
        frontStabAngle = config.frontStabAngle ?? 0
        rearStabSide = config.rearStabSide ?? .none
        rearStabWeight = config.rearStabWeight ?? 0
        rearStabVertAngle = config.rearStabVertAngle ?? 0
        rearStabHorizAngle = config.rearStabHorizAngle ?? 0

        // Recurve / barebow
        braceHeight = config.braceHeight ?? 8.5
        braceHeightText = UnitFormatting.lengthValue(inches: braceHeight, system: unitSystem, digits: 3)
        tillerTop = config.tillerTop ?? 0
        tillerBottom = config.tillerBottom ?? 0
        plungerTension = config.plungerTension ?? 12
        clickerPosition = config.clickerPosition ?? 0
        rearStabLeftWeight = config.rearStabLeftWeight ?? 6
        rearStabRightWeight = config.rearStabRightWeight ?? 6

        let arrow = viewModel.pendingArrowConfig ?? viewModel.activeArrowConfig
        selectedArrowConfig = arrow
        baselineArrowId = arrow?.id
    }

    // MARK: - Draft & apply

    /// Start from the baseline (preserves bow-type-specific nil slots) and only overwrite
    /// the fields this bow type actually exposes in the form.
    private var currentDraft: BowConfiguration {
        var draft = baselineConfig
        draft.drawLength = drawLength
        draft.restVertical = restVertical
        draft.restHorizontal = restHorizontal
        draft.restDepth = restDepth
        draft.gripAngle = gripAngle
        draft.nockingHeight = nockingHeight

        switch bowType {
        case .compound:
            draft.letOffPct = letOffPct
            draft.peepHeight = peepHeight
            draft.dLoopLength = dLoopLength
            draft.topCableTwists = topCableTwists
            draft.bottomCableTwists = bottomCableTwists
            draft.mainStringTopTwists = mainStringTopTwists
            draft.mainStringBottomTwists = mainStringBottomTwists
            draft.topLimbTurns = topLimbTurns
            draft.bottomLimbTurns = bottomLimbTurns
            draft.sightPosition = sightPosition
            draft.frontStabWeight = frontStabWeight
            draft.frontStabAngle = frontStabAngle
            draft.rearStabSide = rearStabSide
            draft.rearStabWeight = rearStabWeight
            draft.rearStabVertAngle = rearStabVertAngle
            draft.rearStabHorizAngle = rearStabHorizAngle
        case .recurve:
            draft.braceHeight = braceHeight
            draft.tillerTop = tillerTop
            draft.tillerBottom = tillerBottom
            draft.plungerTension = plungerTension
            draft.clickerPosition = clickerPosition
            draft.frontStabWeight = frontStabWeight
            draft.frontStabAngle = frontStabAngle
            draft.rearStabLeftWeight = rearStabLeftWeight
            draft.rearStabRightWeight = rearStabRightWeight
            draft.rearStabVertAngle = rearStabVertAngle
            draft.rearStabHorizAngle = rearStabHorizAngle
        case .barebow:
            draft.braceHeight = braceHeight
            draft.tillerTop = tillerTop
            draft.tillerBottom = tillerBottom
            draft.plungerTension = plungerTension
        }
        return draft
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
        arrow.specSummary(system: unitSystem)
    }

    // MARK: - Input rows

    private var drawLengthRow: some View {
        lengthRow(label: "Draw Length", binding: $drawLength,
                  range: .drawLength, digits: unitSystem == .imperial ? 2 : 1)
    }

    private var peepHeightRow: some View {
        lengthRow(label: "Peep Height", binding: $peepHeight,
                  range: .peepHeight, digits: unitSystem == .imperial ? 2 : 1)
    }

    private var dLoopLengthRow: some View {
        mirroredLengthRow(label: "D-Loop Length", binding: $dLoopLength,
                          text: $dLoopText, range: .dLoopLength, digits: 3)
    }

    private var braceHeightRow: some View {
        mirroredLengthRow(label: "Brace Height", binding: $braceHeight,
                          text: $braceHeightText, range: .braceHeight, digits: 3)
    }

    @ViewBuilder
    private func lengthRow(label: String,
                           binding: Binding<Double>,
                           range: UnitRange,
                           digits: Int) -> some View {
        LabeledContent(label) {
            HStack(spacing: 8) {
                Button { bump(binding, range: range, direction: .down) } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain).foregroundStyle(Color.appAccent)

                HStack(spacing: 2) {
                    TextField(UnitFormatting.lengthSuffix(unitSystem), text: Binding(
                        get: { UnitFormatting.lengthValue(inches: binding.wrappedValue, system: unitSystem, digits: digits) },
                        set: { if let v = UnitFormatting.parseLength($0, system: unitSystem) { binding.wrappedValue = v } }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 72)
                    Text(UnitFormatting.lengthSuffix(unitSystem)).foregroundStyle(.secondary)
                }

                Button { bump(binding, range: range, direction: .up) } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain).foregroundStyle(Color.appAccent)
            }
        }
    }

    @ViewBuilder
    private func mirroredLengthRow(label: String,
                                   binding: Binding<Double>,
                                   text: Binding<String>,
                                   range: UnitRange,
                                   digits: Int) -> some View {
        LabeledContent(label) {
            HStack(spacing: 8) {
                Button {
                    bump(binding, range: range, direction: .down)
                    text.wrappedValue = UnitFormatting.lengthValue(inches: binding.wrappedValue, system: unitSystem, digits: digits)
                } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.plain).foregroundStyle(Color.appAccent)

                HStack(spacing: 2) {
                    TextField(UnitFormatting.lengthSuffix(unitSystem), text: text)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 72)
                        .onChange(of: text.wrappedValue) { _, val in
                            if let v = UnitFormatting.parseLength(val, system: unitSystem) {
                                binding.wrappedValue = v
                            }
                        }
                    Text(UnitFormatting.lengthSuffix(unitSystem)).foregroundStyle(.secondary)
                }

                Button {
                    bump(binding, range: range, direction: .up)
                    text.wrappedValue = UnitFormatting.lengthValue(inches: binding.wrappedValue, system: unitSystem, digits: digits)
                } label: { Image(systemName: "plus.circle") }
                .buttonStyle(.plain).foregroundStyle(Color.appAccent)
            }
        }
    }

    private enum Bump { case up, down }

    private func bump(_ binding: Binding<Double>, range: UnitRange, direction: Bump) {
        let bounds = range.displayRange(unitSystem)
        let step = range.displayStep(unitSystem)
        let display = UnitScale.inchToCm.toDisplay(binding.wrappedValue, system: unitSystem)
        let next = direction == .up
            ? min(bounds.upperBound, display + step)
            : max(bounds.lowerBound, display - step)
        binding.wrappedValue = UnitScale.inchToCm.toCanonical(next, system: unitSystem)
    }

    // MARK: - Unit-less formatters

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
            .contentShape(Rectangle())
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
    let bow = Bow(id: "b1", userId: "u1", name: "My Hoyt", bowType: .compound, createdAt: Date())
    let vm = SessionViewModel()
    vm.selectedBow = bow
    vm.activeBowConfig = BowConfiguration.makeDefault(for: bow)
    vm.activeArrowConfig = appState.arrowConfigs.first
    vm.isSessionActive = true
    return SessionConfigSheet(appState: appState, viewModel: vm)
}
