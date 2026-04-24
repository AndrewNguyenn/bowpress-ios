import SwiftUI

struct BowConfigEditView: View {
    var bow: Bow
    var baseConfig: BowConfiguration
    var appState: AppState
    var isSetup: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(LocalStore.self) private var store
    @Environment(\.isReadOnly) private var isReadOnly
    @State private var showingPaywall = false
    @AppStorage(UnitSystem.storageKey) private var unitSystem: UnitSystem = .imperial

    @State private var label = ""

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

    // Recurve
    @State private var braceHeight: Double = 8.5
    @State private var braceHeightText: String = "8.5"
    @State private var tillerTop: Double = 0
    @State private var tillerBottom: Double = 0
    @State private var plungerTension: Int = 12
    @State private var clickerPosition: Double = 0
    @State private var rearStabLeftWeight: Double = 6
    @State private var rearStabRightWeight: Double = 6

    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section { UnitToggle(system: $unitSystem) }

                Section("Label") {
                    TextField("Optional label", text: $label)
                        .accessibilityIdentifier("bow_config_label_field")
                }

                switch bow.bowType {
                case .compound: compoundSections
                case .recurve:  recurveSections
                case .barebow:  barebowSections
                }
            }
            .navigationTitle(isSetup ? "Set Up Bow" : "Log Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            if isReadOnly { showingPaywall = true } else { Task { await save() } }
                        }
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
            .sheet(isPresented: $showingPaywall) {
                NavigationStack { PaywallView() }
            }
            .onAppear { seedFromBase() }
            .onChange(of: unitSystem) { _, new in
                // Re-render mirror text fields in the new system.
                dLoopText      = UnitFormatting.lengthValue(inches: dLoopLength,  system: new, digits: 3)
                braceHeightText = UnitFormatting.lengthValue(inches: braceHeight, system: new, digits: 3)
            }
        }
    }

    // MARK: - Compound form

    @ViewBuilder
    private var compoundSections: some View {
        if isSetup {
            Section("Bow Setup") {
                drawLengthRow
                Stepper(value: $letOffPct, in: 40...99, step: 1) {
                    LabeledContent("Let-off", value: UnitFormatting.percent(letOffPct))
                }
                peepHeightRow
                dLoopLengthRow
            }
        } else {
            Section("Base Setup") {
                Text(baseConfig.compactSetupLine(system: unitSystem))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
            if rearStabSide == .both {
                Stepper(
                    value: $rearStabLeftWeight.displayed(in: unitSystem, scale: .ounceToGram),
                    in: UnitRange.rearStabWeight.displayRange(unitSystem),
                    step: UnitRange.rearStabWeight.displayStep(unitSystem)
                ) {
                    LabeledContent("Left Weight",
                                   value: UnitFormatting.stabWeight(ounces: rearStabLeftWeight, system: unitSystem))
                }
                Stepper(
                    value: $rearStabRightWeight.displayed(in: unitSystem, scale: .ounceToGram),
                    in: UnitRange.rearStabWeight.displayRange(unitSystem),
                    step: UnitRange.rearStabWeight.displayStep(unitSystem)
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
            } else if rearStabSide != .none {
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

    // MARK: - Shared rest section

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

    // MARK: - Seed

    private func seedFromBase() {
        label = ""
        drawLength = baseConfig.drawLength
        restVertical = 0
        restHorizontal = 0
        restDepth = 0
        sightPosition = 0
        gripAngle = 0
        nockingHeight = 0

        switch bow.bowType {
        case .compound:
            letOffPct = baseConfig.letOffPct ?? 80
            peepHeight = baseConfig.peepHeight ?? 9.0
            dLoopLength = baseConfig.dLoopLength ?? 2.0
            dLoopText = UnitFormatting.lengthValue(inches: dLoopLength, system: unitSystem, digits: 3)
            frontStabWeight = baseConfig.frontStabWeight ?? 0
            frontStabAngle = baseConfig.frontStabAngle ?? 0
            rearStabSide = baseConfig.rearStabSide ?? .none
            rearStabWeight = baseConfig.rearStabWeight ?? 0
            rearStabLeftWeight = baseConfig.rearStabLeftWeight ?? 0
            rearStabRightWeight = baseConfig.rearStabRightWeight ?? 0
            rearStabVertAngle = baseConfig.rearStabVertAngle ?? 0
            rearStabHorizAngle = baseConfig.rearStabHorizAngle ?? 0
            topCableTwists = 0; bottomCableTwists = 0
            mainStringTopTwists = 0; mainStringBottomTwists = 0
            topLimbTurns = 0; bottomLimbTurns = 0
        case .recurve:
            braceHeight = baseConfig.braceHeight ?? 8.5
            braceHeightText = UnitFormatting.lengthValue(inches: braceHeight, system: unitSystem, digits: 3)
            tillerTop = baseConfig.tillerTop ?? 0
            tillerBottom = baseConfig.tillerBottom ?? 0
            plungerTension = baseConfig.plungerTension ?? 12
            clickerPosition = baseConfig.clickerPosition ?? 0
            frontStabWeight = baseConfig.frontStabWeight ?? 6
            frontStabAngle = baseConfig.frontStabAngle ?? 0
            rearStabLeftWeight = baseConfig.rearStabLeftWeight ?? 6
            rearStabRightWeight = baseConfig.rearStabRightWeight ?? 6
            rearStabVertAngle = baseConfig.rearStabVertAngle ?? 0
            rearStabHorizAngle = baseConfig.rearStabHorizAngle ?? 0
        case .barebow:
            braceHeight = baseConfig.braceHeight ?? 8.5
            braceHeightText = UnitFormatting.lengthValue(inches: braceHeight, system: unitSystem, digits: 3)
            tillerTop = baseConfig.tillerTop ?? 0
            tillerBottom = baseConfig.tillerBottom ?? 0
            plungerTension = baseConfig.plungerTension ?? 12
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true

        var newConfig = BowConfiguration(
            id: UUID().uuidString,
            bowId: bow.id,
            createdAt: Date(),
            label: label.trimmingCharacters(in: .whitespaces).isEmpty ? nil : label.trimmingCharacters(in: .whitespaces),
            drawLength: drawLength,
            restVertical: restVertical,
            restHorizontal: restHorizontal,
            restDepth: restDepth,
            gripAngle: gripAngle,
            nockingHeight: nockingHeight
        )

        switch bow.bowType {
        case .compound:
            newConfig.sightPosition = sightPosition
            newConfig.letOffPct = letOffPct
            newConfig.peepHeight = peepHeight
            newConfig.dLoopLength = dLoopLength
            newConfig.topCableTwists = topCableTwists
            newConfig.bottomCableTwists = bottomCableTwists
            newConfig.mainStringTopTwists = mainStringTopTwists
            newConfig.mainStringBottomTwists = mainStringBottomTwists
            newConfig.topLimbTurns = topLimbTurns
            newConfig.bottomLimbTurns = bottomLimbTurns
            newConfig.frontStabWeight = frontStabWeight
            newConfig.frontStabAngle = frontStabAngle
            newConfig.rearStabSide = rearStabSide
            if rearStabSide == .both {
                newConfig.rearStabWeight = nil
                newConfig.rearStabLeftWeight = rearStabLeftWeight
                newConfig.rearStabRightWeight = rearStabRightWeight
            } else {
                newConfig.rearStabWeight = rearStabWeight
                newConfig.rearStabLeftWeight = nil
                newConfig.rearStabRightWeight = nil
            }
            newConfig.rearStabVertAngle = rearStabVertAngle
            newConfig.rearStabHorizAngle = rearStabHorizAngle
        case .recurve:
            newConfig.braceHeight = braceHeight
            newConfig.tillerTop = tillerTop
            newConfig.tillerBottom = tillerBottom
            newConfig.plungerTension = plungerTension
            newConfig.clickerPosition = clickerPosition
            newConfig.frontStabWeight = frontStabWeight
            newConfig.frontStabAngle = frontStabAngle
            newConfig.rearStabLeftWeight = rearStabLeftWeight
            newConfig.rearStabRightWeight = rearStabRightWeight
            newConfig.rearStabVertAngle = rearStabVertAngle
            newConfig.rearStabHorizAngle = rearStabHorizAngle
        case .barebow:
            newConfig.braceHeight = braceHeight
            newConfig.tillerTop = tillerTop
            newConfig.tillerBottom = tillerBottom
            newConfig.plungerTension = plungerTension
        }

        do {
            try store.save(config: newConfig)
            Task {
                if let _ = try? await APIClient.shared.createConfiguration(newConfig) {
                    try? store.markBowConfigSynced(id: newConfig.id)
                }
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    // MARK: - Input rows

    private var drawLengthRow: some View {
        lengthRow(
            label: "Draw Length",
            binding: $drawLength,
            range: .drawLength,
            digits: unitSystem == .imperial ? 2 : 1
        )
    }

    private var peepHeightRow: some View {
        lengthRow(
            label: "Peep Height",
            binding: $peepHeight,
            range: .peepHeight,
            digits: unitSystem == .imperial ? 2 : 1
        )
    }

    private var dLoopLengthRow: some View {
        mirroredLengthRow(
            label: "D-Loop Length",
            binding: $dLoopLength,
            text: $dLoopText,
            range: .dLoopLength,
            digits: 3
        )
    }

    private var braceHeightRow: some View {
        mirroredLengthRow(
            label: "Brace Height",
            binding: $braceHeight,
            text: $braceHeightText,
            range: .braceHeight,
            digits: 3
        )
    }

    /// Length row whose TextField is a live reflection of the bound double —
    /// used where the value never needs to outlive body re-renders.
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

    /// Length row with a mirrored `@State` text so the field preserves
    /// partial user input (e.g. "2.") between keystrokes.
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

    /// Nudges an inches-stored binding by one step in the active display system,
    /// clamping to the display range. Works the same in imperial and metric.
    private func bump(_ binding: Binding<Double>, range: UnitRange, direction: Bump) {
        let bounds = range.displayRange(unitSystem)
        let step = range.displayStep(unitSystem)
        let display = UnitScale.inchToCm.toDisplay(binding.wrappedValue, system: unitSystem)
        let next = direction == .up
            ? min(bounds.upperBound, display + step)
            : max(bounds.lowerBound, display - step)
        binding.wrappedValue = UnitScale.inchToCm.toCanonical(next, system: unitSystem)
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

}

// MARK: - Previews

#Preview("Set Up Bow") {
    let bow = Bow(id: "b1", userId: "u1", name: "My Hoyt", bowType: .compound, createdAt: Date())
    BowConfigEditView(bow: bow, baseConfig: .makeDefault(for: bow), appState: AppState(), isSetup: true)
}

#Preview("Set Up Recurve") {
    let bow = Bow(id: "b2", userId: "u1", name: "My Recurve", bowType: .recurve, createdAt: Date())
    BowConfigEditView(bow: bow, baseConfig: .makeDefault(for: bow), appState: AppState(), isSetup: true)
}

#Preview("Set Up Barebow") {
    let bow = Bow(id: "b3", userId: "u1", name: "My Barebow", bowType: .barebow, createdAt: Date())
    BowConfigEditView(bow: bow, baseConfig: .makeDefault(for: bow), appState: AppState(), isSetup: true)
}
