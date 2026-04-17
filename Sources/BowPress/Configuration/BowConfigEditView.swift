import SwiftUI

struct BowConfigEditView: View {
    var bow: Bow
    var baseConfig: BowConfiguration
    var appState: AppState
    var isSetup: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var label = ""
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

    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Label") {
                    TextField("Optional label", text: $label)
                }

                if isSetup {
                    Section("Bow Setup") {
                        Stepper(value: $drawLength, in: 24.0...32.0, step: 0.5) {
                            LabeledContent("Draw Length", value: "\(String(format: "%.1f", drawLength))\"")
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Let-off")
                                Spacer()
                                Text("\(Int(letOffPct))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $letOffPct, in: 60...90, step: 5)
                        }
                        Stepper(value: $peepHeight, in: 0.0...24.0, step: 0.25) {
                            LabeledContent("Peep Height", value: "\(String(format: "%.2f", peepHeight))\"")
                        }
                        LabeledContent("D-Loop Length") {
                            HStack(spacing: 8) {
                                Button {
                                    dLoopLength = max(0.5, (dLoopLength * 16 - 1) / 16)
                                    dLoopText = String(format: "%g", dLoopLength)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.appAccent)

                                TextField("in", text: $dLoopText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 60)
                                    .onChange(of: dLoopText) { _, val in
                                        if let v = Double(val) { dLoopLength = v }
                                    }

                                Text("\"")
                                    .foregroundStyle(.secondary)

                                Button {
                                    dLoopLength = (dLoopLength * 16 + 1) / 16
                                    dLoopText = String(format: "%g", dLoopLength)
                                } label: {
                                    Image(systemName: "plus.circle")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.appAccent)
                            }
                        }
                    }
                } else {
                    Section("Base Setup") {
                        Text("Draw \(String(format: "%.1f", baseConfig.drawLength))\" · Let-off \(Int(baseConfig.letOffPct))% · Peep \(String(format: "%.2f", baseConfig.peepHeight))\" · D-loop \(String(format: "%.3f", baseConfig.dLoopLength))\"")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("String & Cable") {
                    Stepper(value: $topCableTwists, in: -20...20) {
                        LabeledContent("Top Cable", value: halfTwistLabel(topCableTwists))
                    }
                    Stepper(value: $bottomCableTwists, in: -20...20) {
                        LabeledContent("Bottom Cable", value: halfTwistLabel(bottomCableTwists))
                    }
                    Stepper(value: $mainStringTopTwists, in: -20...20) {
                        LabeledContent("Main String Top", value: halfTwistLabel(mainStringTopTwists))
                    }
                    Stepper(value: $mainStringBottomTwists, in: -20...20) {
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
                    Stepper(value: $restVertical, in: -32...32) {
                        LabeledContent("Vertical", value: sixteenthLabel(restVertical))
                    }
                    Stepper(value: $restHorizontal, in: -32...32) {
                        LabeledContent("Horizontal", value: sixteenthLabel(restHorizontal))
                    }
                    Stepper(value: $restDepth, in: -2.0...2.0, step: 0.25) {
                        LabeledContent("Depth", value: "\(String(format: "%.2f", restDepth))\"")
                    }
                }

                Section("Sight, Grip & Nock") {
                    Stepper(value: $sightPosition, in: -5...5) {
                        LabeledContent("Sight Position", value: sightPosition == 0 ? "0 (baseline)" : "\(sightPosition > 0 ? "+" : "")\(sightPosition)")
                    }
                    Stepper(value: $gripAngle, in: 0.0...90.0, step: 0.5) {
                        LabeledContent("Grip Angle", value: "\(String(format: "%.1f", gripAngle))°")
                    }
                    Stepper(value: $nockingHeight, in: -32...32) {
                        LabeledContent("Nocking Height", value: sixteenthLabel(nockingHeight))
                    }
                }

                Section("Front Stabilizer") {
                    Stepper(value: $frontStabWeight, in: 0...30, step: 0.5) {
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
                        Stepper(value: $rearStabWeight, in: 0...20, step: 0.5) {
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
                            Task { await save() }
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
            .onAppear {
                seedFromBase()
            }
        }
    }

    private func seedFromBase() {
        label = ""
        // Always inherit absolute setup values
        drawLength = baseConfig.drawLength
        letOffPct = baseConfig.letOffPct
        peepHeight = baseConfig.peepHeight
        dLoopLength = baseConfig.dLoopLength
        dLoopText = String(format: "%g", baseConfig.dLoopLength)
        // Stabilizers carry over (same gear)
        frontStabWeight = baseConfig.frontStabWeight
        frontStabAngle = baseConfig.frontStabAngle
        rearStabSide = baseConfig.rearStabSide
        rearStabWeight = baseConfig.rearStabWeight
        rearStabVertAngle = baseConfig.rearStabVertAngle
        rearStabHorizAngle = baseConfig.rearStabHorizAngle
        // Delta fields always start at zero
        topCableTwists = 0
        bottomCableTwists = 0
        mainStringTopTwists = 0
        mainStringBottomTwists = 0
        topLimbTurns = 0
        bottomLimbTurns = 0
        restVertical = 0
        restHorizontal = 0
        restDepth = 0
        sightPosition = 0
        gripAngle = 0
        nockingHeight = 0
    }

    private func save() async {
        isSaving = true
        let newConfig = BowConfiguration(
            id: UUID().uuidString,
            bowId: bow.id,
            createdAt: Date(),
            label: label.trimmingCharacters(in: .whitespaces).isEmpty ? nil : label.trimmingCharacters(in: .whitespaces),
            drawLength: drawLength,
            letOffPct: letOffPct,
            peepHeight: peepHeight,
            dLoopLength: dLoopLength,
            topCableTwists: topCableTwists,
            bottomCableTwists: bottomCableTwists,
            mainStringTopTwists: mainStringTopTwists,
            mainStringBottomTwists: mainStringBottomTwists,
            topLimbTurns: topLimbTurns,
            bottomLimbTurns: bottomLimbTurns,
            restVertical: restVertical,
            restHorizontal: restHorizontal,
            restDepth: restDepth,
            sightPosition: sightPosition,
            gripAngle: gripAngle,
            nockingHeight: nockingHeight,
            frontStabWeight: frontStabWeight,
            frontStabAngle: frontStabAngle,
            rearStabSide: rearStabSide,
            rearStabWeight: rearStabWeight,
            rearStabVertAngle: rearStabVertAngle,
            rearStabHorizAngle: rearStabHorizAngle
        )
        do {
            _ = try await APIClient.shared.createConfiguration(newConfig)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
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
    let bow = Bow(id: "b1", userId: "u1", name: "My Hoyt", brand: "Hoyt", model: "Carbon RX-8", createdAt: Date())
    BowConfigEditView(bow: bow, baseConfig: .makeDefault(for: bow.id), appState: AppState(), isSetup: true)
}

#Preview("Log Tuning") {
    let bow = Bow(id: "b1", userId: "u1", name: "My Hoyt", brand: "Hoyt", model: "Carbon RX-8", createdAt: Date())
    let setup = BowConfiguration(
        id: "c1", bowId: "b1",
        createdAt: Date().addingTimeInterval(-86400 * 7),
        label: "Initial Setup",
        drawLength: 28.5, letOffPct: 80,
        peepHeight: 9.25, dLoopLength: 2.0,
        topCableTwists: 0, bottomCableTwists: 0,
        mainStringTopTwists: 0, mainStringBottomTwists: 0,
        topLimbTurns: 0, bottomLimbTurns: 0,
        restVertical: 0, restHorizontal: 0, restDepth: 0,
        sightPosition: 0, gripAngle: 0, nockingHeight: 0,
        frontStabWeight: 14, frontStabAngle: 5,
        rearStabSide: .left, rearStabWeight: 10, rearStabVertAngle: -45, rearStabHorizAngle: 45
    )
    BowConfigEditView(bow: bow, baseConfig: setup, appState: AppState(), isSetup: false)
}
