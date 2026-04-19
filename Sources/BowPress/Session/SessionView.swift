import SwiftUI

struct SessionView: View {
    var appState: AppState
    @Bindable var viewModel: SessionViewModel

    @State private var showConfigSheet = false
    @State private var showEndConfirmation = false
    @State private var isEnding = false
    @State private var isStarting = false
    @State private var selectedBow: Bow? = nil
    @State private var selectedArrow: ArrowConfiguration? = nil

    var body: some View {
        Group {
            if viewModel.isSessionActive {
                activeSessionContent
            } else {
                sessionStartView
            }
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isSessionActive)
        .alert("End Session?", isPresented: $showEndConfirmation) {
            Button("End Session", role: .destructive) {
                Task { await endSession() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will end your session. This cannot be undone.")
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    // MARK: - Session Start

    @ViewBuilder
    private var sessionStartView: some View {
        List {
            Section("Bow") {
                if appState.bows.isEmpty {
                    Text("No bows configured. Add one in the Configure tab.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(appState.bows) { bow in
                        StartPickerRow(
                            title: bow.name,
                            subtitle: "\(bow.brand) \(bow.model)",
                            isSelected: selectedBow?.id == bow.id
                        ) { selectedBow = bow }
                        .listRowBackground(selectedBow?.id == bow.id ? Color.appAccent : nil)
                    }
                    .onMove { from, to in
                        appState.bows.move(fromOffsets: from, toOffset: to)
                    }
                }
            }

            Section("Arrows") {
                if appState.arrowConfigs.isEmpty {
                    Text("No arrow configs. Add one in the Configure tab.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(appState.arrowConfigs) { arrow in
                        StartPickerRow(
                            title: arrow.label,
                            subtitle: arrowSubtitle(arrow),
                            isSelected: selectedArrow?.id == arrow.id
                        ) { selectedArrow = arrow }
                        .listRowBackground(selectedArrow?.id == arrow.id ? Color.appAccent : nil)
                    }
                    .onMove { from, to in
                        appState.arrowConfigs.move(fromOffsets: from, toOffset: to)
                    }
                }
            }

            Section {
                Button {
                    Task { await startNewSession() }
                } label: {
                    HStack {
                        Spacer()
                        if isStarting {
                            HStack(spacing: 8) {
                                ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(0.85)
                                Text("Starting…").fontWeight(.semibold)
                            }
                        } else {
                            Text("Start Session").fontWeight(.semibold)
                        }
                        Spacer()
                    }
                    .frame(height: 44)
                }
                .listRowBackground(
                    (selectedBow != nil && selectedArrow != nil)
                        ? Color.appAccent : Color.appAccent.opacity(0.3)
                )
                .foregroundStyle(.white)
                .disabled(selectedBow == nil || selectedArrow == nil || isStarting)
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(.active))
        .onAppear {
            if selectedBow == nil { selectedBow = appState.bows.first }
            if selectedArrow == nil { selectedArrow = appState.arrowConfigs.first }
        }
    }

    private func arrowSubtitle(_ arrow: ArrowConfiguration) -> String {
        [String(format: "%.2f\"", arrow.length),
         "\(arrow.pointWeight)gr",
         arrow.fletchingType.rawValue].joined(separator: " · ")
    }

    private func startNewSession() async {
        guard let bow = selectedBow, let arrow = selectedArrow else { return }
        isStarting = true
        let configs = (try? await APIClient.shared.fetchConfigurations(bowId: bow.id)) ?? []
        let latestConfig = configs.sorted { $0.createdAt > $1.createdAt }.first
            ?? BowConfiguration.makeDefault(for: bow.id)
        await viewModel.startSession(bow: bow, bowConfig: latestConfig, arrowConfig: arrow)
        isStarting = false
    }

    // MARK: - Active Session Layout

    @ViewBuilder
    private var activeSessionContent: some View {
        ScrollView {
            VStack(spacing: 0) {

                // MARK: Config Banner
                configBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // MARK: Target (current end only — clears when end is completed)
                TargetPlotView(
                    arrows: viewModel.currentEndArrows,
                    onArrowPlotted: { ring, zone, plotX, plotY in
                        Task { await viewModel.plotArrow(ring: ring, zone: zone, plotX: plotX, plotY: plotY) }
                    },
                    isEnabled: !viewModel.isLoading,
                    arrowDiameterMm: (viewModel.pendingArrowConfig ?? viewModel.activeArrowConfig)?.shaftDiameter?.rawValue ?? 5.0
                )
                .frame(maxWidth: 380)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

                if viewModel.isLoading {
                    ProgressView()
                        .padding(.bottom, 4)
                }

                // MARK: Undo
                if !viewModel.currentEndArrows.isEmpty {
                    Button {
                        viewModel.removeLastArrow()
                    } label: {
                        Label("Undo Last Arrow", systemImage: "arrow.uturn.backward")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .padding(.bottom, 8)
                }

                // MARK: Complete End button
                Button {
                    Task { await viewModel.completeEnd(notes: nil) }
                } label: {
                    Label("Complete End \(viewModel.currentEndNumber)", systemImage: "checkmark.circle")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
                .disabled(viewModel.currentEndArrows.isEmpty || viewModel.isLoading)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                // MARK: Session Notes
                VStack(alignment: .leading, spacing: 6) {
                    Label("Session Notes", systemImage: "note.text")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)

                    ZStack(alignment: .topLeading) {
                        if viewModel.sessionNotes.isEmpty {
                            Text("How does it feel? Hold, release, back tension…")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $viewModel.sessionNotes)
                            .font(.body)
                            .frame(minHeight: 90)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                Divider().padding(.horizontal, 20)

                // MARK: Ends history
                endsHistory
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                Divider().padding(.horizontal, 20)

                // MARK: End Session
                Button(role: .destructive) {
                    showEndConfirmation = true
                } label: {
                    HStack {
                        if isEnding {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .scaleEffect(0.85)
                        } else {
                            Image(systemName: "stop.circle.fill")
                        }
                        Text(isEnding ? "Ending…" : "End Session")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
                .disabled(isEnding)
            }
        }
        .sheet(isPresented: $showConfigSheet) {
            SessionConfigSheet(appState: appState, viewModel: viewModel)
        }
    }

    // MARK: - Config Banner

    @ViewBuilder
    private var configBanner: some View {
        VStack(spacing: 0) {
            if viewModel.hasPendingConfigChange {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.orange)
                        .font(.system(size: 14, weight: .semibold))
                    Text("Config changed — plot an arrow to confirm new config")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 6)
            }

            HStack(spacing: 10) {
                // Bow info
                let displayBowConfig = viewModel.pendingBowConfig ?? viewModel.activeBowConfig
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.selectedBow?.name ?? "—")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    if let config = displayBowConfig {
                        Text(config.label ?? "Config · \(String(format: "%.1f\"", config.drawLength))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                // Arrow info
                let displayArrow = viewModel.pendingArrowConfig ?? viewModel.activeArrowConfig
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayArrow?.label ?? "—")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    if let arrow = displayArrow {
                        Text(String(format: "%.2f\" · %dgr", arrow.length, arrow.pointWeight))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    showConfigSheet = true
                } label: {
                    Label("Change", systemImage: "slider.horizontal.3")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appAccent.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Ends History

    @ViewBuilder
    private var endsHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Session summary header
            HStack {
                Text("End \(viewModel.currentEndNumber)  ·  \(viewModel.allArrows.count) arrow\(viewModel.allArrows.count == 1 ? "" : "s")")
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                if !viewModel.allArrows.isEmpty {
                    let total = viewModel.allArrows.reduce(0) { $0 + min($1.ring, 10) }
                    let avg = Double(total) / Double(viewModel.allArrows.count)
                    Text(String(format: "Avg %.1f", avg))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)

            // Completed ends
            ForEach(Array(viewModel.completedEnds.enumerated()), id: \.element.id) { idx, end in
                if idx < viewModel.endArrowCounts.count {
                    let startIdx = viewModel.endArrowCounts.prefix(idx).reduce(0, +)
                    let count = viewModel.endArrowCounts[idx]
                    let safeEnd = min(startIdx + count, viewModel.allArrows.count)
                    let arrows = Array(viewModel.allArrows[startIdx..<safeEnd])
                    EndRow(end: end, arrows: arrows, isCurrent: false)
                }
            }

            // Current in-progress end
            if !viewModel.currentEndArrows.isEmpty {
                EndRow(end: nil, endNumber: viewModel.currentEndNumber,
                       arrows: viewModel.currentEndArrows, isCurrent: true)
            }
        }
    }

    // MARK: - End Session

    private func endSession() async {
        isEnding = true
        await viewModel.endSession()
        isEnding = false
    }
}

// MARK: - End Row

struct EndRow: View {
    var end: SessionEnd?
    var endNumber: Int = 0
    var arrows: [ArrowPlot]
    var isCurrent: Bool

    private var displayNumber: Int { end?.endNumber ?? endNumber }
    private var total: Int { arrows.reduce(0) { $0 + min($1.ring, 10) } }
    private var average: Double {
        guard !arrows.isEmpty else { return 0 }
        return Double(total) / Double(arrows.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text("End \(displayNumber)")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(isCurrent ? Color.appAccent : .primary)
                if isCurrent {
                    Text("IN PROGRESS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer()
                Text(String(format: "Total %d  ·  Avg %.1f", total, average))
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(arrows) { arrow in RingBadge(ring: arrow.ring) }
                }
            }
            .frame(height: 28)
            if let notes = end?.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.top, 1)
            }
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Start Picker Row

private struct StartPickerRow: View {
    var title: String
    var subtitle: String
    var isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body).fontWeight(.semibold)
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(subtitle).font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.75) : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ring Badge

struct RingBadge: View {
    var ring: Int

    var body: some View {
        Text(ring == 11 ? "X" : "\(ring)")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(textColor)
            .frame(width: 24, height: 24)
            .background(bgColor)
            .clipShape(Circle())
    }

    private var bgColor: Color {
        switch ring {
        case 11: return Color(red: 1.0,  green: 0.85, blue: 0.0)   // gold   (X)
        case 10: return Color(red: 1.0,  green: 0.95, blue: 0.2)   // yellow
        case 9:  return Color(red: 1.0,  green: 0.95, blue: 0.2)   // yellow (still yellow zone)
        case 8:  return Color(red: 0.88, green: 0.28, blue: 0.22)  // red
        case 7:  return Color(red: 0.88, green: 0.28, blue: 0.22)  // red
        case 6:  return Color(red: 0.0,  green: 0.73, blue: 0.89)  // blue
        default: return .gray
        }
    }

    private var textColor: Color {
        ring >= 9 ? .black : .white
    }
}

// MARK: - Previews

#Preview("Active Session") {
    let appState = AppState()
    appState.bows = [
        Bow(id: "b1", userId: "u1", name: "My Hoyt", brand: "Hoyt", model: "Carbon RX-8", createdAt: Date())
    ]
    appState.arrowConfigs = [
        ArrowConfiguration(
            id: "a1", userId: "u1", label: "Match Arrows",
            brand: "Easton", model: "X10",
            length: 28.5, pointWeight: 110,
            fletchingType: .vane, fletchingLength: 2.0, fletchingOffset: 1.5
        )
    ]
    let vm = SessionViewModel()
    vm.isSessionActive = true
    vm.selectedBow = appState.bows.first
    vm.activeBowConfig = BowConfiguration.makeDefault(for: "b1")
    vm.activeArrowConfig = appState.arrowConfigs.first
    vm.currentSession = ShootingSession(
        id: "s1", bowId: "b1", bowConfigId: "bc1", arrowConfigId: "a1",
        startedAt: Date(), endedAt: nil, notes: "", feelTags: [], conditions: nil, arrowCount: 0
    )
    vm.allArrows = [
        ArrowPlot(id: "1", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "a1",
                  ring: 10, zone: .center, shotAt: Date(), excluded: false, notes: nil),
        ArrowPlot(id: "2", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "a1",
                  ring: 9, zone: .ne, shotAt: Date(), excluded: false, notes: nil),
        ArrowPlot(id: "3", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "a1",
                  ring: 8, zone: .w, shotAt: Date(), excluded: false, notes: nil),
    ]

    return NavigationStack {
        SessionView(appState: appState, viewModel: vm)
    }
}

#Preview("Pending Config Change") {
    let appState = AppState()
    appState.bows = [
        Bow(id: "b1", userId: "u1", name: "My Hoyt", brand: "Hoyt", model: "Carbon RX-8", createdAt: Date())
    ]
    appState.arrowConfigs = [
        ArrowConfiguration(
            id: "a1", userId: "u1", label: "Match Arrows",
            brand: "Easton", model: "X10",
            length: 28.5, pointWeight: 110,
            fletchingType: .vane, fletchingLength: 2.0, fletchingOffset: 1.5
        )
    ]
    let vm = SessionViewModel()
    vm.isSessionActive = true
    vm.selectedBow = appState.bows.first
    vm.activeBowConfig = BowConfiguration.makeDefault(for: "b1")
    vm.activeArrowConfig = appState.arrowConfigs.first
    var pending = BowConfiguration.makeDefault(for: "b1")
    pending.drawLength = 28.5
    vm.pendingBowConfig = pending
    vm.currentSession = ShootingSession(
        id: "s1", bowId: "b1", bowConfigId: "bc1", arrowConfigId: "a1",
        startedAt: Date(), endedAt: nil, notes: "", feelTags: [], conditions: nil, arrowCount: 0
    )

    return NavigationStack {
        SessionView(appState: appState, viewModel: vm)
    }
}

#Preview("Start — Ready") {
    let appState = AppState()
    appState.bows = [
        Bow(id: "b1", userId: "u1", name: "My Hoyt", brand: "Hoyt", model: "Carbon RX-8", createdAt: Date())
    ]
    appState.arrowConfigs = [
        ArrowConfiguration(
            id: "a1", userId: "u1", label: "Match Arrows",
            brand: "Easton", model: "X10",
            length: 28.5, pointWeight: 110,
            fletchingType: .vane, fletchingLength: 2.0, fletchingOffset: 1.5
        )
    ]
    return NavigationStack {
        SessionView(appState: appState, viewModel: SessionViewModel())
    }
}

#Preview("Start — No Equipment") {
    return NavigationStack {
        SessionView(appState: AppState(), viewModel: SessionViewModel())
    }
}
