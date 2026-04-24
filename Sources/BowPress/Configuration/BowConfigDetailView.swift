import SwiftUI

struct BowConfigDetailView: View {
    var config: BowConfiguration
    var bow: Bow
    var appState: AppState
    var isSetup: Bool

    @State private var showEditSheet = false
    @AppStorage(UnitSystem.storageKey) private var unitSystem: UnitSystem = .imperial

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Form {
            Section { UnitToggle(system: $unitSystem) }

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
                row("Draw Length", value: UnitFormatting.length(inches: config.drawLength, system: unitSystem, digits: 1))
                row("Let-off", value: UnitFormatting.percent(config.letOffPct ?? 0))
                row("Peep Height", value: UnitFormatting.length(inches: config.peepHeight ?? 0, system: unitSystem))
                row("D-Loop Length", value: UnitFormatting.length(inches: config.dLoopLength ?? 0, system: unitSystem, digits: 3))
            }
        } else {
            Section("Base Setup") {
                Text(config.compactSetupLine(system: unitSystem))
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
            deltaRow("Grip Angle", value: UnitFormatting.degrees(config.gripAngle), isChanged: config.gripAngle != 0)
            deltaRow("Nocking Height",
                     value: UnitFormatting.sixteenths(config.nockingHeight, system: unitSystem),
                     isChanged: config.nockingHeight != 0)
        }

        Section("Front Stabilizer") {
            let w = config.frontStabWeight ?? 0
            row("Weight", value: w == 0 ? "None" : UnitFormatting.stabWeight(ounces: w, system: unitSystem))
            row("Angle", value: UnitFormatting.degrees(config.frontStabAngle ?? 0, digits: 0))
        }

        Section("Rear Stabilizer") {
            let side = config.rearStabSide ?? .none
            row("Side", value: side.label)
            if side == .both {
                row("Left Weight", value: UnitFormatting.stabWeight(ounces: config.rearStabLeftWeight ?? 0, system: unitSystem))
                row("Right Weight", value: UnitFormatting.stabWeight(ounces: config.rearStabRightWeight ?? 0, system: unitSystem))
                row("Vertical Angle", value: UnitFormatting.degrees(config.rearStabVertAngle ?? 0, digits: 0))
                row("Horizontal Angle", value: UnitFormatting.degrees(config.rearStabHorizAngle ?? 0, digits: 0))
            } else if side != .none {
                row("Weight", value: UnitFormatting.stabWeight(ounces: config.rearStabWeight ?? 0, system: unitSystem))
                row("Vertical Angle", value: UnitFormatting.degrees(config.rearStabVertAngle ?? 0, digits: 0))
                row("Horizontal Angle", value: UnitFormatting.degrees(config.rearStabHorizAngle ?? 0, digits: 0))
            }
        }
    }

    // MARK: - Recurve

    @ViewBuilder
    private var recurveSections: some View {
        Section("Bow Setup") {
            row("Draw Length", value: UnitFormatting.length(inches: config.drawLength, system: unitSystem, digits: 1))
            row("Brace Height", value: UnitFormatting.length(inches: config.braceHeight ?? 0, system: unitSystem, digits: 3))
        }

        Section("Tiller") {
            let t = config.tillerTop ?? 0
            let b = config.tillerBottom ?? 0
            deltaRow("Top",    value: UnitFormatting.mmLength(t, system: unitSystem), isChanged: t != 0)
            deltaRow("Bottom", value: UnitFormatting.mmLength(b, system: unitSystem), isChanged: b != 0)
        }

        Section("Plunger") {
            row("Tension", value: "\(config.plungerTension ?? 0) clicks")
        }

        Section("Clicker") {
            let c = config.clickerPosition ?? 0
            deltaRow("Position", value: UnitFormatting.mmLength(c, system: unitSystem, digits: 0), isChanged: c != 0)
        }

        Section("Grip & Nock") {
            deltaRow("Grip Angle", value: UnitFormatting.degrees(config.gripAngle), isChanged: config.gripAngle != 0)
            deltaRow("Nocking Height",
                     value: UnitFormatting.sixteenths(config.nockingHeight, system: unitSystem),
                     isChanged: config.nockingHeight != 0)
        }

        Section("Front Stabilizer") {
            row("Weight", value: UnitFormatting.stabWeight(ounces: config.frontStabWeight ?? 0, system: unitSystem))
            row("Angle",  value: UnitFormatting.degrees(config.frontStabAngle ?? 0, digits: 0))
        }

        Section("V-Bar (Rear Stabilizer)") {
            row("Left Weight",  value: UnitFormatting.stabWeight(ounces: config.rearStabLeftWeight ?? 0, system: unitSystem))
            row("Right Weight", value: UnitFormatting.stabWeight(ounces: config.rearStabRightWeight ?? 0, system: unitSystem))
            row("Vertical Angle",  value: UnitFormatting.degrees(config.rearStabVertAngle ?? 0, digits: 0))
            row("Horizontal Angle", value: UnitFormatting.degrees(config.rearStabHorizAngle ?? 0, digits: 0))
        }
    }

    // MARK: - Barebow

    @ViewBuilder
    private var barebowSections: some View {
        Section("Bow Setup") {
            row("Draw Length", value: UnitFormatting.length(inches: config.drawLength, system: unitSystem, digits: 1))
            row("Brace Height", value: UnitFormatting.length(inches: config.braceHeight ?? 0, system: unitSystem, digits: 3))
        }

        Section("Tiller") {
            let t = config.tillerTop ?? 0
            let b = config.tillerBottom ?? 0
            deltaRow("Top",    value: UnitFormatting.mmLength(t, system: unitSystem), isChanged: t != 0)
            deltaRow("Bottom", value: UnitFormatting.mmLength(b, system: unitSystem), isChanged: b != 0)
        }

        Section("Plunger") {
            row("Tension", value: "\(config.plungerTension ?? 0) clicks")
        }

        Section("Grip & Nock") {
            deltaRow("Grip Angle", value: UnitFormatting.degrees(config.gripAngle), isChanged: config.gripAngle != 0)
            deltaRow("Nocking Height",
                     value: UnitFormatting.sixteenths(config.nockingHeight, system: unitSystem),
                     isChanged: config.nockingHeight != 0)
        }
    }

    @ViewBuilder
    private var restDisplaySection: some View {
        Section("Rest") {
            deltaRow("Vertical",
                     value: UnitFormatting.sixteenths(config.restVertical, system: unitSystem),
                     isChanged: config.restVertical != 0)
            deltaRow("Horizontal",
                     value: UnitFormatting.sixteenths(config.restHorizontal, system: unitSystem),
                     isChanged: config.restHorizontal != 0)
            deltaRow("Depth",
                     value: UnitFormatting.length(inches: config.restDepth, system: unitSystem),
                     isChanged: config.restDepth != 0)
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
