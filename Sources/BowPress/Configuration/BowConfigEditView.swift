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
                Section("Label") {
                    TextField("Optional label", text: $label)
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
        }
    }

    // MARK: - Compound form

    @ViewBuilder
    private var compoundSections: some View {
        if isSetup {
            Section("Bow Setup") {
                drawLengthRow
                Stepper(value: $letOffPct, in: 40...99, step: 1) {
                    LabeledContent("Let-off", value: "\(Int(letOffPct))%")
                }
                peepHeightRow
                dLoopLengthRow
            }
        } else {
            Section("Base Setup") {
                Text("Draw \(String(format: "%.1f", baseConfig.drawLength))\" · Let-off \(Int(baseConfig.letOffPct ?? 0))% · Peep \(String(format: "%.2f", baseConfig.peepHeight ?? 0))\" · D-loop \(String(format: "%.3f", baseConfig.dLoopLength ?? 0))\"")
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

    // MARK: - Recurve form

    @ViewBuilder
    private var recurveSections: some View {
        Section("Bow Setup") {
            drawLengthRow
            braceHeightRow
        }

        Section("Tiller") {
            Stepper(value: $tillerTop, in: -10.0...10.0, step: 0.5) {
                LabeledContent("Top Tiller", value: String(format: "%+.1f mm", tillerTop))
            }
            Stepper(value: $tillerBottom, in: -10.0...10.0, step: 0.5) {
                LabeledContent("Bottom Tiller", value: String(format: "%+.1f mm", tillerBottom))
            }
        }

        Section("Plunger") {
            Stepper(value: $plungerTension, in: 0...30) {
                LabeledContent("Tension", value: "\(plungerTension) clicks")
            }
        }

        Section("Clicker") {
            Stepper(value: $clickerPosition, in: -50...50, step: 1) {
                LabeledContent("Position", value: String(format: "%+.0f mm", clickerPosition))
            }
        }

        Section("Grip & Nock") {
            Stepper(value: $gripAngle, in: 0.0...90.0, step: 0.5) {
                LabeledContent("Grip Angle", value: "\(String(format: "%.1f", gripAngle))°")
            }
            Stepper(value: $nockingHeight, in: -80...80) {
                LabeledContent("Nocking Height", value: sixteenthLabel(nockingHeight))
            }
        }

        Section("Front Stabilizer") {
            Stepper(value: $frontStabWeight, in: 0...30, step: 0.5) {
                LabeledContent("Weight", value: "\(String(format: "%g", frontStabWeight)) oz")
            }
            Stepper(value: $frontStabAngle, in: 0...10, step: 1) {
                LabeledContent("Angle", value: "\(Int(frontStabAngle))°")
            }
        }

        Section("V-Bar (Rear Stabilizer)") {
            Stepper(value: $rearStabLeftWeight, in: 0...30, step: 0.5) {
                LabeledContent("Left Weight", value: "\(String(format: "%g", rearStabLeftWeight)) oz")
            }
            Stepper(value: $rearStabRightWeight, in: 0...30, step: 0.5) {
                LabeledContent("Right Weight", value: "\(String(format: "%g", rearStabRightWeight)) oz")
            }
            Stepper(value: $rearStabVertAngle, in: -90...90, step: 5) {
                LabeledContent("Vertical Angle", value: "\(Int(rearStabVertAngle))°")
            }
            Stepper(value: $rearStabHorizAngle, in: 0...90, step: 5) {
                LabeledContent("Horizontal Angle", value: "\(Int(rearStabHorizAngle))°")
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
            Stepper(value: $tillerTop, in: -10.0...10.0, step: 0.5) {
                LabeledContent("Top Tiller", value: String(format: "%+.1f mm", tillerTop))
            }
            Stepper(value: $tillerBottom, in: -10.0...10.0, step: 0.5) {
                LabeledContent("Bottom Tiller", value: String(format: "%+.1f mm", tillerBottom))
            }
        }

        Section("Plunger") {
            Stepper(value: $plungerTension, in: 0...30) {
                LabeledContent("Tension", value: "\(plungerTension) clicks")
            }
        }

        Section("Grip & Nock") {
            Stepper(value: $gripAngle, in: 0.0...90.0, step: 0.5) {
                LabeledContent("Grip Angle", value: "\(String(format: "%.1f", gripAngle))°")
            }
            Stepper(value: $nockingHeight, in: -80...80) {
                LabeledContent("Nocking Height", value: sixteenthLabel(nockingHeight))
            }
        }
    }

    // MARK: - Shared rest section

    @ViewBuilder
    private var restSection: some View {
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
            dLoopText = String(format: "%g", dLoopLength)
            frontStabWeight = baseConfig.frontStabWeight ?? 0
            frontStabAngle = baseConfig.frontStabAngle ?? 0
            rearStabSide = baseConfig.rearStabSide ?? .none
            rearStabWeight = baseConfig.rearStabWeight ?? 0
            rearStabVertAngle = baseConfig.rearStabVertAngle ?? 0
            rearStabHorizAngle = baseConfig.rearStabHorizAngle ?? 0
            topCableTwists = 0; bottomCableTwists = 0
            mainStringTopTwists = 0; mainStringBottomTwists = 0
            topLimbTurns = 0; bottomLimbTurns = 0
        case .recurve:
            braceHeight = baseConfig.braceHeight ?? 8.5
            braceHeightText = String(format: "%g", braceHeight)
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
            braceHeightText = String(format: "%g", braceHeight)
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
            newConfig.rearStabWeight = rearStabWeight
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

    private var dLoopLengthRow: some View {
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

    private var braceHeightRow: some View {
        LabeledContent("Brace Height") {
            HStack(spacing: 8) {
                Button {
                    braceHeight = max(5.0, (braceHeight * 16 - 1) / 16)
                    braceHeightText = String(format: "%g", braceHeight)
                } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.plain).foregroundStyle(Color.appAccent)

                HStack(spacing: 2) {
                    TextField("in", text: $braceHeightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                        .onChange(of: braceHeightText) { _, val in
                            if let v = Double(val) { braceHeight = v }
                        }
                    Text("\"").foregroundStyle(.secondary)
                }

                Button {
                    braceHeight = min(12.0, (braceHeight * 16 + 1) / 16)
                    braceHeightText = String(format: "%g", braceHeight)
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
        let sign = n > 0 ? "+" : "-"
        return "\(sign)\(abs(n))/16\""
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
