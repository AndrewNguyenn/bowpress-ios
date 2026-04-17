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
            }

            if isSetup {
                Section("Bow Setup") {
                    row("Draw Length", value: "\(String(format: "%.1f", config.drawLength))\"")
                    row("Let-off", value: "\(Int(config.letOffPct))%")
                    row("Peep Height", value: "\(String(format: "%.2f", config.peepHeight))\"")
                    row("D-Loop Length", value: "\(String(format: "%.3f", config.dLoopLength))\"")
                }
            } else {
                Section("Base Setup") {
                    Text("Draw \(String(format: "%.1f", config.drawLength))\" · Let-off \(Int(config.letOffPct))% · Peep \(String(format: "%.2f", config.peepHeight))\" · D-loop \(String(format: "%.3f", config.dLoopLength))\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("String & Cable") {
                deltaRow("Top Cable Twists", value: halfTwistLabel(config.topCableTwists), isChanged: config.topCableTwists != 0)
                deltaRow("Bottom Cable Twists", value: halfTwistLabel(config.bottomCableTwists), isChanged: config.bottomCableTwists != 0)
                deltaRow("Main String Top Twists", value: halfTwistLabel(config.mainStringTopTwists), isChanged: config.mainStringTopTwists != 0)
                deltaRow("Main String Bottom Twists", value: halfTwistLabel(config.mainStringBottomTwists), isChanged: config.mainStringBottomTwists != 0)
            }

            Section("Limbs") {
                deltaRow("Top Limb", value: limbTurnsLabel(config.topLimbTurns), isChanged: config.topLimbTurns != 0)
                deltaRow("Bottom Limb", value: limbTurnsLabel(config.bottomLimbTurns), isChanged: config.bottomLimbTurns != 0)
            }

            Section("Rest") {
                deltaRow("Vertical", value: sixteenthLabel(config.restVertical), isChanged: config.restVertical != 0)
                deltaRow("Horizontal", value: sixteenthLabel(config.restHorizontal), isChanged: config.restHorizontal != 0)
                deltaRow("Depth", value: "\(String(format: "%.2f", config.restDepth))\"", isChanged: config.restDepth != 0)
            }

            Section("Sight, Grip & Nock") {
                deltaRow(
                    "Sight Position",
                    value: config.sightPosition == 0 ? "0 (baseline)" : "\(config.sightPosition > 0 ? "+" : "")\(config.sightPosition)",
                    isChanged: config.sightPosition != 0
                )
                deltaRow("Grip Angle", value: "\(String(format: "%.1f", config.gripAngle))°", isChanged: config.gripAngle != 0)
                deltaRow("Nocking Height", value: sixteenthLabel(config.nockingHeight), isChanged: config.nockingHeight != 0)
            }

            Section("Front Stabilizer") {
                row("Weight", value: config.frontStabWeight == 0 ? "None" : "\(String(format: "%g", config.frontStabWeight)) oz")
                row("Angle", value: "\(String(format: "%.0f", config.frontStabAngle))°")
            }

            Section("Rear Stabilizer") {
                row("Side", value: config.rearStabSide.label)
                if config.rearStabSide != .none {
                    row("Weight", value: "\(String(format: "%g", config.rearStabWeight)) oz")
                    row("Vertical Angle", value: "\(Int(config.rearStabVertAngle))°")
                    row("Horizontal Angle", value: "\(Int(config.rearStabHorizAngle))°")
                }
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

#Preview("Setup") {
    let bow = Bow(id: "b1", userId: "u1", name: "My Hoyt", brand: "Hoyt", model: "Carbon RX-8", createdAt: Date())
    let config = BowConfiguration(
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
    NavigationStack {
        BowConfigDetailView(config: config, bow: bow, appState: AppState(), isSetup: true)
    }
}

#Preview("Tuning Record") {
    let bow = Bow(id: "b1", userId: "u1", name: "My Hoyt", brand: "Hoyt", model: "Carbon RX-8", createdAt: Date())
    let config = BowConfiguration(
        id: "c2", bowId: "b1",
        createdAt: Date().addingTimeInterval(-86400),
        label: "Pre-tournament",
        drawLength: 28.5, letOffPct: 80,
        peepHeight: 9.25, dLoopLength: 2.0,
        topCableTwists: 2, bottomCableTwists: 2,
        mainStringTopTwists: 1, mainStringBottomTwists: 0,
        topLimbTurns: 0, bottomLimbTurns: 0,
        restVertical: 2, restHorizontal: -1, restDepth: 0,
        sightPosition: 1, gripAngle: 0, nockingHeight: 3,
        frontStabWeight: 14, frontStabAngle: 5,
        rearStabSide: .left, rearStabWeight: 10, rearStabVertAngle: -45, rearStabHorizAngle: 45
    )
    NavigationStack {
        BowConfigDetailView(config: config, bow: bow, appState: AppState(), isSetup: false)
    }
}
