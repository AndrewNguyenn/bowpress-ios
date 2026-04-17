import SwiftUI

struct SessionView: View {
    var appState: AppState
    @Bindable var viewModel: SessionViewModel

    @State private var showConfigSheet = false
    @State private var showEndConfirmation = false
    @State private var showCompleteEndSheet = false
    @State private var pendingEndNotes = ""
    @State private var isEnding = false

    var body: some View {
        Group {
            if viewModel.isSessionActive {
                activeSessionContent
            } else {
                SessionSetupView(appState: appState, viewModel: viewModel)
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
            Text("Your session notes will be saved. This cannot be undone.")
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

                // MARK: Target
                TargetPlotView(
                    arrows: viewModel.allArrows,
                    onArrowPlotted: { ring, zone, plotX, plotY in
                        Task { await viewModel.plotArrow(ring: ring, zone: zone, plotX: plotX, plotY: plotY) }
                    },
                    isEnabled: !viewModel.isLoading,
                    arrowDiameterMm: viewModel.activeArrowConfig?.shaftDiameter?.rawValue ?? 5.0
                )
                .frame(maxWidth: 380)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

                if viewModel.isLoading {
                    ProgressView()
                        .padding(.bottom, 4)
                }

                // MARK: Complete End button
                Button {
                    showCompleteEndSheet = true
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

                // MARK: Ends history
                endsHistory
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                Divider().padding(.horizontal, 20)

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

                // MARK: Undo
                if !viewModel.allArrows.isEmpty {
                    Button {
                        viewModel.removeLastArrow()
                    } label: {
                        Label("Undo Last Arrow", systemImage: "arrow.uturn.backward")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .padding(.bottom, 10)
                }

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
        .sheet(isPresented: $showCompleteEndSheet) {
            CompleteEndSheet(
                endNumber: viewModel.currentEndNumber,
                arrows: viewModel.currentEndArrows,
                notes: $pendingEndNotes
            ) {
                Task {
                    await viewModel.completeEnd(notes: pendingEndNotes)
                    pendingEndNotes = ""
                    showCompleteEndSheet = false
                }
            }
            .presentationDetents([.medium])
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.selectedBow?.name ?? "—")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    if let config = viewModel.activeBowConfig {
                        Text(config.label ?? "Config · \(String(format: "%.1f\"", config.drawLength))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                // Arrow info
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.activeArrowConfig?.label ?? "—")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    if let arrow = viewModel.activeArrowConfig {
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
                let startIdx = viewModel.endArrowCounts.prefix(idx).reduce(0, +)
                let count = viewModel.endArrowCounts[idx]
                let arrows = Array(viewModel.allArrows[startIdx..<(startIdx + count)])
                EndRow(end: end, arrows: arrows, isCurrent: false)
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

private struct EndRow: View {
    var end: SessionEnd?
    var endNumber: Int = 0
    var arrows: [ArrowPlot]
    var isCurrent: Bool

    private var displayNumber: Int { end?.endNumber ?? endNumber }
    private var score: Int { arrows.reduce(0) { $0 + min($1.ring, 10) } }

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
                Text("Σ \(score)")
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

// MARK: - Complete End Sheet

private struct CompleteEndSheet: View {
    var endNumber: Int
    var arrows: [ArrowPlot]
    @Binding var notes: String
    var onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    private var score: Int { arrows.reduce(0) { $0 + min($1.ring, 10) } }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Score summary
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(arrows.count) arrows").font(.headline)
                        Text("Score: \(score)").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(arrows) { a in RingBadge(ring: a.ring) }
                        }
                    }
                    .frame(maxWidth: 180)
                }
                .padding(14)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Notes
                VStack(alignment: .leading, spacing: 6) {
                    Label("End Notes (optional)", systemImage: "note.text")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.secondary).textCase(.uppercase).tracking(0.4)
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("Form, feel, conditions…")
                                .font(.body).foregroundStyle(.tertiary)
                                .padding(.horizontal, 14).padding(.vertical, 11)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $notes)
                            .font(.body).frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                    }
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Spacer()

                Button(action: onComplete) {
                    Text("Complete End \(endNumber)")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity).frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
            }
            .padding(20)
            .navigationTitle("End \(endNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct RingBadge: View {
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
        case 11: return Color(red: 1.0, green: 0.72, blue: 0.0)
        case 10: return Color(red: 0.98, green: 0.85, blue: 0.12)
        case 9:  return Color(red: 0.88, green: 0.28, blue: 0.22)
        case 8:  return Color(red: 0.42, green: 0.55, blue: 0.72)
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
                  ring: 11, zone: .center, shotAt: Date(), excluded: false, notes: nil),
        ArrowPlot(id: "2", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "a1",
                  ring: 10, zone: .ne, shotAt: Date(), excluded: false, notes: nil),
        ArrowPlot(id: "3", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "a1",
                  ring: 9, zone: .w, shotAt: Date(), excluded: false, notes: nil),
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

#Preview("Setup — Empty State") {
    let vm = SessionViewModel()
    return NavigationStack {
        SessionView(appState: AppState(), viewModel: vm)
    }
}

#Preview("Setup — With Bows") {
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
