import SwiftUI

// MARK: - History entry model

struct TuningHistoryEntry: Identifiable {
    let day: Date
    let config: BowConfiguration
    let brief: String   // which categories changed vs previous day
    var id: Date { day }
}

// MARK: - BowDetailView

struct BowDetailView: View {
    var bow: Bow
    var appState: AppState

    @State private var configurations: [BowConfiguration] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var selectedHistory: TuningHistoryEntry?

    // Bow info
    @State private var name = ""
    @State private var brand = ""
    @State private var model = ""

    // Setup fields
    @State private var drawLength: Double = 28.0
    @State private var drawLengthText: String = "28.0"
    @State private var letOffPct: Double = 80
    @State private var peepHeight: Double = 9.0
    @State private var dLoopLength: Double = 2.0
    @State private var dLoopText: String = "2.0"

    // Delta fields
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

    private var currentConfig: BowConfiguration? {
        configurations.max(by: { $0.createdAt < $1.createdAt })
    }

    private var historyEntries: [TuningHistoryEntry] {
        let sorted = configurations.sorted { $0.createdAt < $1.createdAt }
        guard sorted.count > 1 else { return [] }
        let calendar = Calendar.current

        // Group by day — keep the most recent record per day (skip the first/oldest = setup)
        var dayMap: [Date: BowConfiguration] = [:]
        for config in sorted.dropFirst() {
            let day = calendar.startOfDay(for: config.createdAt)
            if let ex = dayMap[day], config.createdAt <= ex.createdAt { continue }
            dayMap[day] = config
        }

        return dayMap.keys
            .sorted(by: >)
            .compactMap { day -> TuningHistoryEntry? in
                guard let config = dayMap[day] else { return nil }
                let prev = sorted.last(where: { calendar.startOfDay(for: $0.createdAt) < day })
                return TuningHistoryEntry(day: day, config: config, brief: briefDiff(from: prev, to: config))
            }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        Form {
            Section("Bow Info") {
                LabeledContent("Name") {
                    TextField("Name", text: $name).multilineTextAlignment(.trailing)
                }
                LabeledContent("Brand") {
                    TextField("Brand", text: $brand).multilineTextAlignment(.trailing)
                }
                LabeledContent("Model") {
                    TextField("Model", text: $model).multilineTextAlignment(.trailing)
                }
            }

            if isLoading && configurations.isEmpty {
                Section {
                    ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
                }
            } else {
                Section("Setup") {
                    drawLengthRow
                    Stepper(value: $letOffPct, in: 1...100, step: 1) {
                        LabeledContent("Let-off", value: "\(Int(letOffPct))%")
                    }
                    Stepper(value: $peepHeight, in: 0.0...24.0, step: 0.25) {
                        LabeledContent("Peep Height", value: "\(String(format: "%.2f", peepHeight))\"")
                    }
                    LabeledContent("D-Loop") {
                        HStack(spacing: 8) {
                            Button {
                                dLoopLength = max(0.5, (dLoopLength * 16 - 1) / 16)
                                dLoopText = String(format: "%g", dLoopLength)
                            } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain).foregroundStyle(Color.appAccent)

                            TextField("in", text: $dLoopText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 60)
                                .onChange(of: dLoopText) { _, val in
                                    if let v = Double(val) { dLoopLength = v }
                                }

                            Text("\"").foregroundStyle(.secondary)

                            Button {
                                dLoopLength = (dLoopLength * 16 + 1) / 16
                                dLoopText = String(format: "%g", dLoopLength)
                            } label: { Image(systemName: "plus.circle") }
                            .buttonStyle(.plain).foregroundStyle(Color.appAccent)
                        }
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
                        LabeledContent("Sight Position", value: sightPosition == 0 ? "0" : "\(sightPosition > 0 ? "+" : "")\(sightPosition)")
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

                if !historyEntries.isEmpty {
                    Section("History") {
                        ForEach(historyEntries) { entry in
                            Button { selectedHistory = entry } label: {
                                HStack {
                                    Text(Self.dayFormatter.string(from: entry.day))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(entry.brief)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.trailing)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle(bow.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") { Task { await saveCurrentState() } }
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(item: $selectedHistory) { entry in
            if let current = currentConfig {
                HistoryDetailSheet(entry: entry, current: current)
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
        .task { await loadConfigurations() }
    }

    // MARK: - Draw length row (extracted to avoid type-check timeout)

    private var drawLengthRow: some View {
        LabeledContent("Draw Length") {
            HStack(spacing: 8) {
                Button {
                    let next = max(20.0, (drawLength * 4 - 1) / 4)
                    drawLength = next
                    drawLengthText = String(format: "%g", next)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.appAccent)

                TextField("in", text: $drawLengthText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 60)
                    .onChange(of: drawLengthText) { _, val in
                        if let v = Double(val) { drawLength = v }
                    }

                Text("\"").foregroundStyle(.secondary)

                Button {
                    let next = (drawLength * 4 + 1) / 4
                    drawLength = next
                    drawLengthText = String(format: "%g", next)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.appAccent)
            }
        }
    }

    // MARK: - State

    private func seedState() {
        name = bow.name
        brand = bow.brand
        model = bow.model
        let c = currentConfig
        drawLength = c?.drawLength ?? 28.0
        drawLengthText = String(format: "%g", c?.drawLength ?? 28.0)
        letOffPct = c?.letOffPct ?? 80
        peepHeight = c?.peepHeight ?? 9.0
        dLoopLength = c?.dLoopLength ?? 2.0
        dLoopText = String(format: "%g", c?.dLoopLength ?? 2.0)
        topCableTwists = c?.topCableTwists ?? 0
        bottomCableTwists = c?.bottomCableTwists ?? 0
        mainStringTopTwists = c?.mainStringTopTwists ?? 0
        mainStringBottomTwists = c?.mainStringBottomTwists ?? 0
        topLimbTurns = c?.topLimbTurns ?? 0
        bottomLimbTurns = c?.bottomLimbTurns ?? 0
        restVertical = c?.restVertical ?? 0
        restHorizontal = c?.restHorizontal ?? 0
        restDepth = c?.restDepth ?? 0
        sightPosition = c?.sightPosition ?? 0
        gripAngle = c?.gripAngle ?? 0
        nockingHeight = c?.nockingHeight ?? 0
        frontStabWeight = c?.frontStabWeight ?? 0
        frontStabAngle = c?.frontStabAngle ?? 0
        rearStabSide = c?.rearStabSide ?? .none
        rearStabWeight = c?.rearStabWeight ?? 0
        rearStabVertAngle = c?.rearStabVertAngle ?? 0
        rearStabHorizAngle = c?.rearStabHorizAngle ?? 0
    }

    private func saveCurrentState() async {
        isSaving = true
        let newConfig = BowConfiguration(
            id: UUID().uuidString, bowId: bow.id, createdAt: Date(), label: nil,
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
        do {
            _ = try await APIClient.shared.createConfiguration(newConfig)
            await loadConfigurations()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func loadConfigurations() async {
        isLoading = true
        do {
            configurations = try await APIClient.shared.fetchConfigurations(bowId: bow.id)
            seedState()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Diff helpers

    private func briefDiff(from prev: BowConfiguration?, to cur: BowConfiguration) -> String {
        guard let prev else { return "Initial setup" }
        var parts: [String] = []
        if prev.drawLength != cur.drawLength { parts.append("Draw") }
        if prev.letOffPct != cur.letOffPct { parts.append("Let-off") }
        if prev.peepHeight != cur.peepHeight { parts.append("Peep") }
        if prev.dLoopLength != cur.dLoopLength { parts.append("D-loop") }
        if prev.topCableTwists != cur.topCableTwists || prev.bottomCableTwists != cur.bottomCableTwists ||
           prev.mainStringTopTwists != cur.mainStringTopTwists || prev.mainStringBottomTwists != cur.mainStringBottomTwists {
            parts.append("Twists")
        }
        if prev.topLimbTurns != cur.topLimbTurns || prev.bottomLimbTurns != cur.bottomLimbTurns { parts.append("Limbs") }
        if prev.restVertical != cur.restVertical || prev.restHorizontal != cur.restHorizontal || prev.restDepth != cur.restDepth { parts.append("Rest") }
        if prev.sightPosition != cur.sightPosition { parts.append("Sight") }
        if prev.nockingHeight != cur.nockingHeight { parts.append("Nock") }
        if prev.gripAngle != cur.gripAngle { parts.append("Grip") }
        if parts.isEmpty { return "No changes" }
        let shown = parts.prefix(3).joined(separator: " · ")
        return parts.count > 3 ? "\(shown) +\(parts.count - 3)" : shown
    }

    // MARK: - Formatters

    private func halfTwistLabel(_ n: Int) -> String {
        if n == 0 { return "0" }
        let twists = Double(n) / 2.0
        let f = twists == twists.rounded() ? String(format: "%.0f", twists) : String(format: "%g", twists)
        return "\(n > 0 ? "+" : "")\(f) twist\(abs(twists) == 1 ? "" : "s")"
    }

    private func limbTurnsLabel(_ turns: Double) -> String {
        if turns == 0 { return "0" }
        let abs = Swift.abs(turns)
        let dir = turns < 0 ? "out" : "in"
        let f = abs == abs.rounded() ? String(format: "%.0f", abs) : String(format: "%.1f", abs)
        return "\(f) turn\(abs == 1 ? "" : "s") \(dir)"
    }

    private func sixteenthLabel(_ n: Int) -> String {
        if n == 0 { return "0" }
        return "\(n > 0 ? "+" : "-")\(Swift.abs(n))/16\""
    }
}

// MARK: - History detail sheet

private struct HistoryDetailSheet: View {
    let entry: TuningHistoryEntry
    let current: BowConfiguration
    @Environment(\.dismiss) private var dismiss

    struct FieldChange: Identifiable {
        let id = UUID()
        let field: String
        let target: String   // historical value (what you want)
        let from: String     // current value (where you are now)
    }

    private var changes: [FieldChange] {
        let h = entry.config
        var out: [FieldChange] = []

        func add(_ field: String, _ t: String, _ f: String, same: Bool) {
            if !same { out.append(FieldChange(field: field, target: t, from: f)) }
        }

        add("Draw Length",
            "\(String(format: "%.1f", h.drawLength))\"",
            "\(String(format: "%.1f", current.drawLength))\"",
            same: h.drawLength == current.drawLength)
        add("Let-off",
            "\(Int(h.letOffPct))%",
            "\(Int(current.letOffPct))%",
            same: h.letOffPct == current.letOffPct)
        add("Peep Height",
            "\(String(format: "%.2f", h.peepHeight))\"",
            "\(String(format: "%.2f", current.peepHeight))\"",
            same: h.peepHeight == current.peepHeight)
        add("D-Loop",
            "\(String(format: "%.3f", h.dLoopLength))\"",
            "\(String(format: "%.3f", current.dLoopLength))\"",
            same: h.dLoopLength == current.dLoopLength)
        add("Top Cable",
            twistStr(h.topCableTwists), twistStr(current.topCableTwists),
            same: h.topCableTwists == current.topCableTwists)
        add("Bottom Cable",
            twistStr(h.bottomCableTwists), twistStr(current.bottomCableTwists),
            same: h.bottomCableTwists == current.bottomCableTwists)
        add("Main String Top",
            twistStr(h.mainStringTopTwists), twistStr(current.mainStringTopTwists),
            same: h.mainStringTopTwists == current.mainStringTopTwists)
        add("Main String Bottom",
            twistStr(h.mainStringBottomTwists), twistStr(current.mainStringBottomTwists),
            same: h.mainStringBottomTwists == current.mainStringBottomTwists)
        add("Top Limb",
            limbStr(h.topLimbTurns), limbStr(current.topLimbTurns),
            same: h.topLimbTurns == current.topLimbTurns)
        add("Bottom Limb",
            limbStr(h.bottomLimbTurns), limbStr(current.bottomLimbTurns),
            same: h.bottomLimbTurns == current.bottomLimbTurns)
        add("Rest Vertical",
            sixStr(h.restVertical), sixStr(current.restVertical),
            same: h.restVertical == current.restVertical)
        add("Rest Horizontal",
            sixStr(h.restHorizontal), sixStr(current.restHorizontal),
            same: h.restHorizontal == current.restHorizontal)
        add("Rest Depth",
            "\(String(format: "%.2f", h.restDepth))\"",
            "\(String(format: "%.2f", current.restDepth))\"",
            same: h.restDepth == current.restDepth)
        add("Sight Position",
            sightStr(h.sightPosition), sightStr(current.sightPosition),
            same: h.sightPosition == current.sightPosition)
        add("Grip Angle",
            "\(String(format: "%.1f", h.gripAngle))°",
            "\(String(format: "%.1f", current.gripAngle))°",
            same: h.gripAngle == current.gripAngle)
        add("Nocking Height",
            sixStr(h.nockingHeight), sixStr(current.nockingHeight),
            same: h.nockingHeight == current.nockingHeight)

        return out
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                if changes.isEmpty {
                    Section {
                        Text("Same as your current configuration.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(changes) { change in
                            HStack(alignment: .center) {
                                Text(change.field)
                                    .foregroundStyle(.primary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(change.target)
                                        .foregroundStyle(Color.appAccent)
                                        .fontWeight(.semibold)
                                    Text("now: \(change.from)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("To restore this configuration")
                    } footer: {
                        Text("Green = target value · Grey = your current value")
                    }
                }
            }
            .navigationTitle(Self.dayFormatter.string(from: entry.day))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func twistStr(_ n: Int) -> String {
        if n == 0 { return "0" }
        let t = Double(n) / 2.0
        let f = t == t.rounded() ? String(format: "%.0f", t) : String(format: "%g", t)
        return "\(n > 0 ? "+" : "")\(f)"
    }

    private func limbStr(_ t: Double) -> String {
        if t == 0 { return "0" }
        let a = Swift.abs(t)
        let f = a == a.rounded() ? String(format: "%.0f", a) : String(format: "%.1f", a)
        return "\(f) \(t < 0 ? "out" : "in")"
    }

    private func sixStr(_ n: Int) -> String {
        if n == 0 { return "0" }
        return "\(n > 0 ? "+" : "-")\(Swift.abs(n))/16\""
    }

    private func sightStr(_ n: Int) -> String {
        if n == 0 { return "0" }
        return "\(n > 0 ? "+" : "")\(n)"
    }
}

// MARK: - Preview

#Preview {
    let bow = Bow(id: "b1", userId: "u1", name: "My Hoyt", brand: "Hoyt", model: "Carbon RX-8", createdAt: Date())
    let appState = AppState()
    appState.bows = [bow]
    return NavigationStack {
        BowDetailView(bow: bow, appState: appState)
    }
}
