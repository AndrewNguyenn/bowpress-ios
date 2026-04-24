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

    @Environment(LocalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isReadOnly) private var isReadOnly

    @State private var configurations: [BowConfiguration] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var selectedHistory: TuningHistoryEntry?
    @State private var showDeleteConfirm = false
    @State private var isUpdatingReference = false
    @State private var showingPaywall = false

    // Bow info
    @State private var name = ""
    @State private var brand = ""
    @State private var model = ""

    // Shared tuning
    @State private var drawLength: Double = 28.0
    @State private var drawLengthText: String = "28.0"
    @State private var restVertical: Int = 0
    @State private var restHorizontal: Int = 0
    @State private var restDepth: Double = 0
    @State private var sightPosition: Int = 0
    @State private var gripAngle: Double = 0
    @State private var nockingHeight: Int = 0

    // Compound
    @State private var letOffPct: Double = 80
    @State private var peepHeight: Double = 9.0
    @State private var peepHeightText: String = "9.0"
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
                LabeledContent("Type", value: bow.bowType.label)
            }

            if isLoading && configurations.isEmpty {
                Section {
                    ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
                }
            } else {
                referenceSection

                switch bow.bowType {
                case .compound: compoundSections
                case .recurve:  recurveSections
                case .barebow:  barebowSections
                }

                if !historyEntries.isEmpty {
                    Section("History") {
                        ForEach(historyEntries) { entry in
                            Button { selectedHistory = entry } label: {
                                HStack(spacing: 6) {
                                    if entry.config.isReference == true {
                                        Image(systemName: "star.fill")
                                            .font(.caption2)
                                            .foregroundStyle(Color.appAccent)
                                    }
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

                Section {
                    Button(role: .destructive) {
                        if isReadOnly { showingPaywall = true } else { showDeleteConfirm = true }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Bow").foregroundStyle(.red)
                            Spacer()
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
                    Button("Save") {
                        if isReadOnly { showingPaywall = true } else { Task { await saveCurrentState() } }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(item: $selectedHistory) { entry in
            if let current = currentConfig {
                HistoryDetailSheet(bowType: bow.bowType, entry: entry, current: current)
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
        .alert("Delete \(bow.name)?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { showDeleteConfirm = false }
            Button("Delete", role: .destructive) {
                if let err = deleteBowEverywhere(bow, appState: appState, store: store) {
                    errorMessage = err.localizedDescription
                } else {
                    dismiss()
                }
            }
        } message: {
            Text("This permanently removes this bow along with its tuning history and shooting sessions. This cannot be undone.")
        }
        .sheet(isPresented: $showingPaywall) {
            NavigationStack { PaywallView() }
        }
        .task { await loadConfigurations() }
    }

    // MARK: - Reference pin

    @ViewBuilder
    private var referenceSection: some View {
        if let ref = configurations.first(where: { $0.isReference == true }) {
            Section("Reference") {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.appAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ref.label ?? "Pinned configuration")
                            .font(.body.weight(.semibold))
                        if let score = ref.avgArrowScore {
                            Text("Score \(Int(score)) / 100 · \(ref.referenceManuallyPinned == true ? "Manually pinned" : "Auto-selected by analytics")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(ref.referenceManuallyPinned == true ? "Manually pinned" : "Auto-selected by analytics")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if ref.referenceManuallyPinned == true {
                        Button("Unpin", role: .destructive) {
                            if isReadOnly { showingPaywall = true } else { Task { await updateReferencePin(configId: ref.id, pinned: false) } }
                        }
                        .disabled(isUpdatingReference)
                    }
                }
            }
        }

        // If there's a current config that isn't the reference (or no reference yet),
        // offer a "Pin current as reference" affordance. Only show when the current
        // config is scoreable OR there's no reference at all.
        if let cur = currentConfig,
           cur.isReference != true,
           (cur.scoreable == true || !configurations.contains(where: { $0.isReference == true })) {
            Section {
                Button {
                    if isReadOnly { showingPaywall = true } else { Task { await updateReferencePin(configId: cur.id, pinned: true) } }
                } label: {
                    HStack {
                        Image(systemName: "star")
                        Text("Pin current config as reference")
                        Spacer()
                        if isUpdatingReference { ProgressView().scaleEffect(0.8) }
                    }
                }
                .disabled(isUpdatingReference)
            } footer: {
                Text("Analytics comparisons anchor to your reference. Unpinning lets the pipeline auto-select the highest-scoring config after each session.")
                    .font(.caption2)
            }
        }
    }

    private func updateReferencePin(configId: String, pinned: Bool) async {
        isUpdatingReference = true
        defer { isUpdatingReference = false }
        do {
            let updated = try await APIClient.shared.setReferenceConfiguration(id: configId, pinned: pinned)
            // Mirror the update locally — every config for this bow reflects the new pin state.
            if pinned {
                for i in configurations.indices {
                    configurations[i].isReference = (configurations[i].id == configId)
                    configurations[i].referenceManuallyPinned = (configurations[i].id == configId)
                }
            } else {
                for i in configurations.indices where configurations[i].id == configId {
                    configurations[i].isReference = false
                    configurations[i].referenceManuallyPinned = false
                }
            }
            // Persist the cached flag change so a reopen reflects immediately.
            try? store.save(config: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Compound form

    @ViewBuilder
    private var compoundSections: some View {
        Section("Setup") {
            drawLengthRow
            Stepper(value: $letOffPct, in: 40...99, step: 1) {
                LabeledContent("Let-off", value: "\(Int(letOffPct))%")
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
                LabeledContent("Sight Position", value: sightPosition == 0 ? "0" : "\(sightPosition > 0 ? "+" : "")\(sightPosition)")
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
            if rearStabSide == .both {
                Stepper(value: $rearStabLeftWeight, in: 0...60, step: 0.5) {
                    LabeledContent("Left Weight", value: "\(String(format: "%g", rearStabLeftWeight)) oz")
                }
                Stepper(value: $rearStabRightWeight, in: 0...60, step: 0.5) {
                    LabeledContent("Right Weight", value: "\(String(format: "%g", rearStabRightWeight)) oz")
                }
                Stepper(value: $rearStabVertAngle, in: -90...90, step: 5) {
                    LabeledContent("Vertical Angle", value: "\(Int(rearStabVertAngle))°")
                }
                Stepper(value: $rearStabHorizAngle, in: 0...90, step: 5) {
                    LabeledContent("Horizontal Angle", value: "\(Int(rearStabHorizAngle))°")
                }
            } else if rearStabSide != .none {
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
        Section("Setup") {
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
        Section("Setup") {
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

    // MARK: - Shared

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

    // MARK: - Input rows

    private var peepHeightRow: some View {
        LabeledContent("Peep Height") {
            HStack(spacing: 8) {
                Button {
                    let next = max(3.0, (peepHeight * 10 - 1) / 10)
                    peepHeight = next
                    peepHeightText = String(format: "%g", next)
                } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.plain).foregroundStyle(Color.appAccent)

                HStack(spacing: 2) {
                    TextField("in", text: $peepHeightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                        .onChange(of: peepHeightText) { _, val in
                            if let v = Double(val) { peepHeight = v }
                        }
                    Text("\"").foregroundStyle(.secondary)
                }

                Button {
                    let next = min(17.0, (peepHeight * 10 + 1) / 10)
                    peepHeight = next
                    peepHeightText = String(format: "%g", next)
                } label: { Image(systemName: "plus.circle") }
                .buttonStyle(.plain).foregroundStyle(Color.appAccent)
            }
        }
    }

    private var drawLengthRow: some View {
        LabeledContent("Draw Length") {
            HStack(spacing: 8) {
                Button {
                    let next = max(17.0, (drawLength * 4 - 1) / 4)
                    drawLength = next
                    drawLengthText = String(format: "%g", next)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.appAccent)

                HStack(spacing: 2) {
                    TextField("in", text: $drawLengthText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                        .accessibilityIdentifier("bow_draw_length_field")
                        .onChange(of: drawLengthText) { _, val in
                            if let v = Double(val) { drawLength = v }
                        }
                    Text("\"").foregroundStyle(.secondary)
                }

                Button {
                    let next = min(37.0, (drawLength * 4 + 1) / 4)
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

    private var dLoopLengthRow: some View {
        LabeledContent("D-Loop") {
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

    // MARK: - State

    private func seedState() {
        name = bow.name
        brand = bow.brand
        model = bow.model
        let c = currentConfig
        // Fall back to the type-aware defaults when there's no saved config yet.
        let fallback = BowConfiguration.makeDefault(for: bow)

        drawLength = c?.drawLength ?? fallback.drawLength
        drawLengthText = String(format: "%g", drawLength)
        restVertical = c?.restVertical ?? fallback.restVertical
        restHorizontal = c?.restHorizontal ?? fallback.restHorizontal
        restDepth = c?.restDepth ?? fallback.restDepth
        sightPosition = c?.sightPosition ?? fallback.sightPosition ?? 0
        gripAngle = c?.gripAngle ?? fallback.gripAngle
        nockingHeight = c?.nockingHeight ?? fallback.nockingHeight

        // Compound
        letOffPct = c?.letOffPct ?? fallback.letOffPct ?? 80
        peepHeight = c?.peepHeight ?? fallback.peepHeight ?? 9.0
        peepHeightText = String(format: "%g", peepHeight)
        dLoopLength = c?.dLoopLength ?? fallback.dLoopLength ?? 2.0
        dLoopText = String(format: "%g", dLoopLength)
        topCableTwists = c?.topCableTwists ?? 0
        bottomCableTwists = c?.bottomCableTwists ?? 0
        mainStringTopTwists = c?.mainStringTopTwists ?? 0
        mainStringBottomTwists = c?.mainStringBottomTwists ?? 0
        topLimbTurns = c?.topLimbTurns ?? 0
        bottomLimbTurns = c?.bottomLimbTurns ?? 0
        frontStabWeight = c?.frontStabWeight ?? fallback.frontStabWeight ?? 0
        frontStabAngle = c?.frontStabAngle ?? fallback.frontStabAngle ?? 0
        rearStabSide = c?.rearStabSide ?? fallback.rearStabSide ?? .none
        rearStabWeight = c?.rearStabWeight ?? 0
        rearStabVertAngle = c?.rearStabVertAngle ?? fallback.rearStabVertAngle ?? 0
        rearStabHorizAngle = c?.rearStabHorizAngle ?? fallback.rearStabHorizAngle ?? 0

        // Recurve / barebow
        braceHeight = c?.braceHeight ?? fallback.braceHeight ?? 8.5
        braceHeightText = String(format: "%g", braceHeight)
        tillerTop = c?.tillerTop ?? fallback.tillerTop ?? 0
        tillerBottom = c?.tillerBottom ?? fallback.tillerBottom ?? 0
        plungerTension = c?.plungerTension ?? fallback.plungerTension ?? 12
        clickerPosition = c?.clickerPosition ?? fallback.clickerPosition ?? 0
        rearStabLeftWeight = c?.rearStabLeftWeight ?? fallback.rearStabLeftWeight ?? (bow.bowType == .compound ? 0 : 6)
        rearStabRightWeight = c?.rearStabRightWeight ?? fallback.rearStabRightWeight ?? (bow.bowType == .compound ? 0 : 6)
    }

    private func saveCurrentState() async {
        isSaving = true

        var newConfig = BowConfiguration(
            id: UUID().uuidString,
            bowId: bow.id,
            createdAt: Date(),
            label: nil,
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
            appState.bowConfigs[bow.id] = newConfig
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func loadConfigurations() async {
        isLoading = true
        do {
            var fetched = try store.fetchConfigurations(bowId: bow.id)
            // Merge in any config confirmed during an active session that hasn't
            // been persisted to SwiftData yet (AppState is the live source of truth).
            if let live = appState.bowConfigs[bow.id],
               !fetched.contains(where: { $0.id == live.id }) {
                fetched.append(live)
            }
            configurations = fetched
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
        if prev.nockingHeight != cur.nockingHeight { parts.append("Nock") }
        if prev.gripAngle != cur.gripAngle { parts.append("Grip") }

        switch bow.bowType {
        case .compound:
            if prev.restVertical != cur.restVertical || prev.restHorizontal != cur.restHorizontal || prev.restDepth != cur.restDepth { parts.append("Rest") }
            if prev.sightPosition != cur.sightPosition { parts.append("Sight") }
            if prev.letOffPct != cur.letOffPct { parts.append("Let-off") }
            if prev.peepHeight != cur.peepHeight { parts.append("Peep") }
            if prev.dLoopLength != cur.dLoopLength { parts.append("D-loop") }
            if prev.topCableTwists != cur.topCableTwists || prev.bottomCableTwists != cur.bottomCableTwists ||
               prev.mainStringTopTwists != cur.mainStringTopTwists || prev.mainStringBottomTwists != cur.mainStringBottomTwists {
                parts.append("Twists")
            }
            if prev.topLimbTurns != cur.topLimbTurns || prev.bottomLimbTurns != cur.bottomLimbTurns { parts.append("Limbs") }
            if prev.frontStabWeight != cur.frontStabWeight || prev.frontStabAngle != cur.frontStabAngle ||
               prev.rearStabSide != cur.rearStabSide || prev.rearStabWeight != cur.rearStabWeight ||
               prev.rearStabVertAngle != cur.rearStabVertAngle || prev.rearStabHorizAngle != cur.rearStabHorizAngle {
                parts.append("Stabs")
            }
        case .recurve:
            if prev.braceHeight != cur.braceHeight { parts.append("Brace") }
            if prev.tillerTop != cur.tillerTop || prev.tillerBottom != cur.tillerBottom { parts.append("Tiller") }
            if prev.plungerTension != cur.plungerTension { parts.append("Plunger") }
            if prev.clickerPosition != cur.clickerPosition { parts.append("Clicker") }
            if prev.frontStabWeight != cur.frontStabWeight || prev.frontStabAngle != cur.frontStabAngle ||
               prev.rearStabLeftWeight != cur.rearStabLeftWeight || prev.rearStabRightWeight != cur.rearStabRightWeight ||
               prev.rearStabVertAngle != cur.rearStabVertAngle || prev.rearStabHorizAngle != cur.rearStabHorizAngle {
                parts.append("Stabs")
            }
        case .barebow:
            if prev.braceHeight != cur.braceHeight { parts.append("Brace") }
            if prev.tillerTop != cur.tillerTop || prev.tillerBottom != cur.tillerBottom { parts.append("Tiller") }
            if prev.plungerTension != cur.plungerTension { parts.append("Plunger") }
        }

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
    let bowType: BowType
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

        // Shared across all bow types
        add("Draw Length",
            "\(String(format: "%.1f", h.drawLength))\"",
            "\(String(format: "%.1f", current.drawLength))\"",
            same: h.drawLength == current.drawLength)
        add("Grip Angle",
            "\(String(format: "%.1f", h.gripAngle))°",
            "\(String(format: "%.1f", current.gripAngle))°",
            same: h.gripAngle == current.gripAngle)
        add("Nocking Height",
            sixStr(h.nockingHeight), sixStr(current.nockingHeight),
            same: h.nockingHeight == current.nockingHeight)

        switch bowType {
        case .compound:
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
                sightStr(h.sightPosition ?? 0), sightStr(current.sightPosition ?? 0),
                same: h.sightPosition == current.sightPosition)
            add("Let-off",
                "\(Int(h.letOffPct ?? 0))%",
                "\(Int(current.letOffPct ?? 0))%",
                same: h.letOffPct == current.letOffPct)
            add("Peep Height",
                "\(String(format: "%.2f", h.peepHeight ?? 0))\"",
                "\(String(format: "%.2f", current.peepHeight ?? 0))\"",
                same: h.peepHeight == current.peepHeight)
            add("D-Loop",
                "\(String(format: "%.3f", h.dLoopLength ?? 0))\"",
                "\(String(format: "%.3f", current.dLoopLength ?? 0))\"",
                same: h.dLoopLength == current.dLoopLength)
            add("Top Cable",
                twistStr(h.topCableTwists ?? 0), twistStr(current.topCableTwists ?? 0),
                same: h.topCableTwists == current.topCableTwists)
            add("Bottom Cable",
                twistStr(h.bottomCableTwists ?? 0), twistStr(current.bottomCableTwists ?? 0),
                same: h.bottomCableTwists == current.bottomCableTwists)
            add("Main String Top",
                twistStr(h.mainStringTopTwists ?? 0), twistStr(current.mainStringTopTwists ?? 0),
                same: h.mainStringTopTwists == current.mainStringTopTwists)
            add("Main String Bottom",
                twistStr(h.mainStringBottomTwists ?? 0), twistStr(current.mainStringBottomTwists ?? 0),
                same: h.mainStringBottomTwists == current.mainStringBottomTwists)
            add("Top Limb",
                limbStr(h.topLimbTurns ?? 0), limbStr(current.topLimbTurns ?? 0),
                same: h.topLimbTurns == current.topLimbTurns)
            add("Bottom Limb",
                limbStr(h.bottomLimbTurns ?? 0), limbStr(current.bottomLimbTurns ?? 0),
                same: h.bottomLimbTurns == current.bottomLimbTurns)
        case .recurve:
            add("Brace Height",
                "\(String(format: "%.3f", h.braceHeight ?? 0))\"",
                "\(String(format: "%.3f", current.braceHeight ?? 0))\"",
                same: h.braceHeight == current.braceHeight)
            add("Top Tiller",
                String(format: "%+.1f mm", h.tillerTop ?? 0),
                String(format: "%+.1f mm", current.tillerTop ?? 0),
                same: h.tillerTop == current.tillerTop)
            add("Bottom Tiller",
                String(format: "%+.1f mm", h.tillerBottom ?? 0),
                String(format: "%+.1f mm", current.tillerBottom ?? 0),
                same: h.tillerBottom == current.tillerBottom)
            add("Plunger",
                "\(h.plungerTension ?? 0) clicks",
                "\(current.plungerTension ?? 0) clicks",
                same: h.plungerTension == current.plungerTension)
            add("Clicker",
                String(format: "%+.0f mm", h.clickerPosition ?? 0),
                String(format: "%+.0f mm", current.clickerPosition ?? 0),
                same: h.clickerPosition == current.clickerPosition)
            add("V-Bar Vertical Angle",
                "\(Int(h.rearStabVertAngle ?? 0))°",
                "\(Int(current.rearStabVertAngle ?? 0))°",
                same: h.rearStabVertAngle == current.rearStabVertAngle)
            add("V-Bar Horizontal Angle",
                "\(Int(h.rearStabHorizAngle ?? 0))°",
                "\(Int(current.rearStabHorizAngle ?? 0))°",
                same: h.rearStabHorizAngle == current.rearStabHorizAngle)
        case .barebow:
            add("Brace Height",
                "\(String(format: "%.3f", h.braceHeight ?? 0))\"",
                "\(String(format: "%.3f", current.braceHeight ?? 0))\"",
                same: h.braceHeight == current.braceHeight)
            add("Top Tiller",
                String(format: "%+.1f mm", h.tillerTop ?? 0),
                String(format: "%+.1f mm", current.tillerTop ?? 0),
                same: h.tillerTop == current.tillerTop)
            add("Bottom Tiller",
                String(format: "%+.1f mm", h.tillerBottom ?? 0),
                String(format: "%+.1f mm", current.tillerBottom ?? 0),
                same: h.tillerBottom == current.tillerBottom)
            add("Plunger",
                "\(h.plungerTension ?? 0) clicks",
                "\(current.plungerTension ?? 0) clicks",
                same: h.plungerTension == current.plungerTension)
        }

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

#Preview("Compound") {
    let bow = Bow(id: "b1", userId: "u1", name: "My Hoyt", bowType: .compound, createdAt: Date())
    let appState = AppState()
    appState.bows = [bow]
    return NavigationStack {
        BowDetailView(bow: bow, appState: appState)
    }
}

#Preview("Recurve") {
    let bow = Bow(id: "b2", userId: "u1", name: "Olympic Rig", bowType: .recurve, createdAt: Date())
    let appState = AppState()
    appState.bows = [bow]
    return NavigationStack {
        BowDetailView(bow: bow, appState: appState)
    }
}

#Preview("Barebow") {
    let bow = Bow(id: "b3", userId: "u1", name: "Trad", bowType: .barebow, createdAt: Date())
    let appState = AppState()
    appState.bows = [bow]
    return NavigationStack {
        BowDetailView(bow: bow, appState: appState)
    }
}
