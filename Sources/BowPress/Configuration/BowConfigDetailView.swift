import SwiftUI

struct BowConfigDetailView: View {
    var config: BowConfiguration
    var bow: Bow
    var appState: AppState
    var isSetup: Bool

    @State private var showEditSheet = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Form {
            Section {
                LabeledContent("Label", value: config.label ?? (isSetup ? "Initial Setup" : "—"))
                LabeledContent("Recorded", value: Self.dateFormatter.string(from: config.createdAt))
                LabeledContent("Type", value: bow.bowType.label)
            }

            switch bow.bowType {
            case .compound: compoundSections
            case .recurve:  recurveSections
            case .barebow:  barebowSections
            }

            if !isSetup {
                Section {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Log New Tuning", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
        }
        .navigationTitle(isSetup ? "Setup" : (config.label ?? "Tuning Record"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showEditSheet) {
            BowConfigEditView(bow: bow, baseConfig: config, appState: appState, isSetup: false)
        }
    }

    // MARK: - Compound

    @ViewBuilder
    private var compoundSections: some View {
        if isSetup {
            Section("Bow Setup") {
                row("Draw Length", value: "\(String(format: "%.1f", config.drawLength))\"")
                row("Let-off", value: "\(Int(config.letOffPct ?? 0))%")
                row("Peep Height", value: "\(String(format: "%.2f", config.peepHeight ?? 0))\"")
                row("D-Loop Length", value: "\(String(format: "%.3f", config.dLoopLength ?? 0))\"")
            }
        } else {
            Section("Base Setup") {
                Text("Draw \(String(format: "%.1f", config.drawLength))\" · Let-off \(Int(config.letOffPct ?? 0))% · Peep \(String(format: "%.2f", config.peepHeight ?? 0))\" · D-loop \(String(format: "%.3f", config.dLoopLength ?? 0))\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }

        Section("String & Cable") {
            deltaRow("Top Cable Twists", value: halfTwistLabel(config.topCableTwists ?? 0), isChanged: (config.topCableTwists ?? 0) != 0)
            deltaRow("Bottom Cable Twists", value: halfTwistLabel(config.bottomCableTwists ?? 0), isChanged: (config.bottomCableTwists ?? 0) != 0)
            deltaRow("Main String Top Twists", value: halfTwistLabel(config.mainStringTopTwists ?? 0), isChanged: (config.mainStringTopTwists ?? 0) != 0)
            deltaRow("Main String Bottom Twists", value: halfTwistLabel(config.mainStringBottomTwists ?? 0), isChanged: (config.mainStringBottomTwists ?? 0) != 0)
        }

        Section("Limbs") {
            deltaRow("Top Limb", value: limbTurnsLabel(config.topLimbTurns ?? 0), isChanged: (config.topLimbTurns ?? 0) != 0)
            deltaRow("Bottom Limb", value: limbTurnsLabel(config.bottomLimbTurns ?? 0), isChanged: (config.bottomLimbTurns ?? 0) != 0)
        }

        restDisplaySection

        Section("Sight, Grip & Nock") {
            let sp = config.sightPosition ?? 0
            deltaRow(
                "Sight Position",
                value: sp == 0 ? "0 (baseline)" : "\(sp > 0 ? "+" : "")\(sp)",
                isChanged: sp != 0
            )
            deltaRow("Grip Angle", value: "\(String(format: "%.1f", config.gripAngle))°", isChanged: config.gripAngle != 0)
            deltaRow("Nocking Height", value: sixteenthLabel(config.nockingHeight), isChanged: config.nockingHeight != 0)
        }

        Section("Front Stabilizer") {
            let w = config.frontStabWeight ?? 0
            row("Weight", value: w == 0 ? "None" : "\(String(format: "%g", w)) oz")
            row("Angle", value: "\(String(format: "%.0f", config.frontStabAngle ?? 0))°")
        }

        Section("Rear Stabilizer") {
            let side = config.rearStabSide ?? .none
            row("Side", value: side.label)
            if side != .none {
                row("Weight", value: "\(String(format: "%g", config.rearStabWeight ?? 0)) oz")
                row("Vertical Angle", value: "\(Int(config.rearStabVertAngle ?? 0))°")
                row("Horizontal Angle", value: "\(Int(config.rearStabHorizAngle ?? 0))°")
            }
        }
    }

    // MARK: - Recurve

    @ViewBuilder
    private var recurveSections: some View {
        Section("Bow Setup") {
            row("Draw Length", value: "\(String(format: "%.1f", config.drawLength))\"")
            row("Brace Height", value: "\(String(format: "%.3f", config.braceHeight ?? 0))\"")
        }

        Section("Tiller") {
            let t = config.tillerTop ?? 0
            let b = config.tillerBottom ?? 0
            deltaRow("Top", value: String(format: "%+.1f mm", t), isChanged: t != 0)
            deltaRow("Bottom", value: String(format: "%+.1f mm", b), isChanged: b != 0)
        }

        Section("Plunger") {
            row("Tension", value: "\(config.plungerTension ?? 0) clicks")
        }

        Section("Clicker") {
            let c = config.clickerPosition ?? 0
            deltaRow("Position", value: String(format: "%+.0f mm", c), isChanged: c != 0)
        }

        Section("Grip & Nock") {
            deltaRow("Grip Angle", value: "\(String(format: "%.1f", config.gripAngle))°", isChanged: config.gripAngle != 0)
            deltaRow("Nocking Height", value: sixteenthLabel(config.nockingHeight), isChanged: config.nockingHeight != 0)
        }

        Section("Front Stabilizer") {
            row("Weight", value: "\(String(format: "%g", config.frontStabWeight ?? 0)) oz")
            row("Angle", value: "\(String(format: "%.0f", config.frontStabAngle ?? 0))°")
        }

        Section("V-Bar (Rear Stabilizer)") {
            row("Left Weight", value: "\(String(format: "%g", config.rearStabLeftWeight ?? 0)) oz")
            row("Right Weight", value: "\(String(format: "%g", config.rearStabRightWeight ?? 0)) oz")
            row("Vertical Angle", value: "\(Int(config.rearStabVertAngle ?? 0))°")
            row("Horizontal Angle", value: "\(Int(config.rearStabHorizAngle ?? 0))°")
        }
    }

    // MARK: - Barebow

    @ViewBuilder
    private var barebowSections: some View {
        Section("Bow Setup") {
            row("Draw Length", value: "\(String(format: "%.1f", config.drawLength))\"")
            row("Brace Height", value: "\(String(format: "%.3f", config.braceHeight ?? 0))\"")
        }

        Section("Tiller") {
            let t = config.tillerTop ?? 0
            let b = config.tillerBottom ?? 0
            deltaRow("Top", value: String(format: "%+.1f mm", t), isChanged: t != 0)
            deltaRow("Bottom", value: String(format: "%+.1f mm", b), isChanged: b != 0)
        }

        Section("Plunger") {
            row("Tension", value: "\(config.plungerTension ?? 0) clicks")
        }

        Section("Grip & Nock") {
            deltaRow("Grip Angle", value: "\(String(format: "%.1f", config.gripAngle))°", isChanged: config.gripAngle != 0)
            deltaRow("Nocking Height", value: sixteenthLabel(config.nockingHeight), isChanged: config.nockingHeight != 0)
        }
    }

    @ViewBuilder
    private var restDisplaySection: some View {
        Section("Rest") {
            deltaRow("Vertical", value: sixteenthLabel(config.restVertical), isChanged: config.restVertical != 0)
            deltaRow("Horizontal", value: sixteenthLabel(config.restHorizontal), isChanged: config.restHorizontal != 0)
            deltaRow("Depth", value: "\(String(format: "%.2f", config.restDepth))\"", isChanged: config.restDepth != 0)
        }
    }

    @ViewBuilder
    private func row(_ label: String, value: String) -> some View {
        LabeledContent(label, value: value)
    }

    @ViewBuilder
    private func deltaRow(_ label: String, value: String, isChanged: Bool) -> some View {
        LabeledContent(label) {
            Text(value)
                .foregroundStyle(isChanged ? Color.appAccent : .secondary)
                .fontWeight(isChanged ? .semibold : .regular)
        }
    }

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

#Preview("Compound Setup") {
    let bow = Bow(id: "b1", userId: "u1", name: "My Hoyt", bowType: .compound, createdAt: Date())
    let config = BowConfiguration.makeDefault(for: bow)
    NavigationStack {
        BowConfigDetailView(config: config, bow: bow, appState: AppState(), isSetup: true)
    }
}

#Preview("Recurve Setup") {
    let bow = Bow(id: "b2", userId: "u1", name: "My Recurve", bowType: .recurve, createdAt: Date())
    let config = BowConfiguration.makeDefault(for: bow)
    NavigationStack {
        BowConfigDetailView(config: config, bow: bow, appState: AppState(), isSetup: true)
    }
}

#Preview("Barebow Setup") {
    let bow = Bow(id: "b3", userId: "u1", name: "My Barebow", bowType: .barebow, createdAt: Date())
    let config = BowConfiguration.makeDefault(for: bow)
    NavigationStack {
        BowConfigDetailView(config: config, bow: bow, appState: AppState(), isSetup: true)
    }
}
