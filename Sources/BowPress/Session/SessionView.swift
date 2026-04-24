import SwiftUI

struct SessionView: View {
    var appState: AppState
    @Bindable var viewModel: SessionViewModel
    @Environment(LocalStore.self) private var store
    @Environment(\.isReadOnly) private var isReadOnly

    @State private var showConfigSheet = false
    @State private var showEndConfirmation = false
    @State private var showDiscardConfirmation = false
    @State private var isEnding = false
    @State private var isDiscarding = false
    @State private var isStarting = false
    @State private var showingPaywall = false
    @State private var showBowPicker = false
    @State private var showNotesEditor = false
    @State private var selectedBow: Bow? = nil
    @State private var selectedArrow: ArrowConfiguration? = nil
    @State private var selectedFaceType: TargetFaceType = .tenRing
    @State private var userTouchedFace: Bool = false
    /// Last picked distance, persisted across launches. `nil` = unset.
    @AppStorage("session.lastDistance") private var lastDistanceRaw: String = ""
    @State private var selectedDistance: ShootingDistance? = nil
    @AppStorage(UnitSystem.storageKey) private var unitSystem: UnitSystem = .imperial

    /// Live clock so the active-session elapsed timer + pulsing dot re-render.
    @State private var now: Date = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    #if DEBUG
    /// Test-only initialiser — lets snapshot tests pin specific selection state
    /// (distance, face type) without relying on @AppStorage or .onAppear priming.
    /// `mockNow` pins the `now` state variable so both the active-session elapsed
    /// timer and the setup-view time stamp render deterministically.
    init(
        appState: AppState,
        viewModel: SessionViewModel,
        selectedDistance: ShootingDistance? = nil,
        selectedFaceType: TargetFaceType = .tenRing,
        mockNow: Date = Date(timeIntervalSince1970: 1_735_689_600)  // 2025-01-01 00:00 UTC
    ) {
        self.appState = appState
        self._viewModel = Bindable(wrappedValue: viewModel)
        self._selectedDistance = State(initialValue: selectedDistance)
        self._selectedFaceType = State(initialValue: selectedFaceType)
        self._now = State(initialValue: mockNow)
    }
    #endif

    var body: some View {
        Group {
            if viewModel.isSessionActive {
                activeSessionContent
            } else {
                sessionStartView
            }
        }
        .background(Color.appPaper.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(viewModel.isSessionActive)
        .onReceive(tick) { now = $0 }
        .alert("End Session?", isPresented: $showEndConfirmation) {
            Button("End Session", role: .destructive) {
                Task { await endSession() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will end your session. This cannot be undone.")
        }
        .alert("Discard Session?", isPresented: $showDiscardConfirmation) {
            Button("Discard Session", role: .destructive) {
                Task { await discardSession() }
            }
            Button("Keep Shooting", role: .cancel) {}
        } message: {
            Text("All arrows logged will be permanently deleted. This session won't be included in your analytics.")
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
        .sheet(isPresented: $showingPaywall) {
            NavigationStack { PaywallView() }
        }
        .sheet(isPresented: $showBowPicker) {
            BowPickerSheet(
                appState: appState,
                selectedBow: $selectedBow,
                selectedArrow: $selectedArrow,
                selectedFaceType: $selectedFaceType,
                userTouchedFace: $userTouchedFace,
                unitSystem: unitSystem
            )
        }
        .sheet(isPresented: $showNotesEditor) {
            SessionNotesSheet(notes: Binding(
                get: { viewModel.sessionNotes },
                set: {
                    viewModel.sessionNotes = $0
                    viewModel.updateNotes($0)
                }
            ))
        }
    }

    // MARK: - Session Start (Kenrokuen)

    @ViewBuilder
    private var sessionStartView: some View {
        ScrollView {
            VStack(spacing: 0) {
                BPNavHeader(eyebrow: "BOWPRESS · SETUP", title: "Set the stage") {
                    setupStamp
                }

                VStack(spacing: 0) {
                    bowField
                    distanceField
                    targetFaceField
                    intentionField
                    beginCtaBlock
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .onAppear { primeSetupState() }
        .onChange(of: selectedBow?.id) { _, _ in
            guard !userTouchedFace, let bow = selectedBow else { return }
            selectedFaceType = TargetFaceType.defaultFor(bow.bowType)
        }
        .onChange(of: selectedDistance) { _, new in
            lastDistanceRaw = new?.rawValue ?? ""
        }
    }

    // MARK: - Setup stamp block (upper-right of nav header)

    @ViewBuilder
    private var setupStamp: some View {
        // Use `now` (the same State variable as the active-session timer) so that
        // snapshot tests can pin a deterministic date via the DEBUG init.
        VStack(alignment: .trailing, spacing: 0) {
            Text(dateLine(now))
                .font(.bpMono(10, weight: .medium))
                .foregroundStyle(Color.appInk)
            Text(timeLine(now))
                .font(.bpMono(10))
                .foregroundStyle(Color.appInk3)
            Text(sunriseLine())
                .font(.bpMono(10))
                .foregroundStyle(Color.appInk3)
        }
    }

    private func dateLine(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE · MMM d"
        return f.string(from: d).lowercased()
    }

    private func timeLine(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "H:mm"
        let h = Calendar.current.component(.hour, from: d)
        let band: String
        switch h {
        case 5..<11:  band = "morning"
        case 11..<14: band = "midday"
        case 14..<18: band = "afternoon"
        case 18..<21: band = "evening"
        default:      band = "night"
        }
        return "\(f.string(from: d)) · \(band)"
    }

    private func sunriseLine() -> String {
        // Fixed string — matches the reference design. Real sunrise calc
        // is out of scope for chrome work.
        return "sunrise 5:58"
    }

    // MARK: - Bow field

    @ViewBuilder
    private var bowField: some View {
        VStack(alignment: .leading, spacing: 10) {
            fieldLabel("BOW", hint: "tap to change")
            Button { showBowPicker = true } label: { bowCard }
                .buttonStyle(.plain)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.appLine).frame(height: 1)
        }
    }

    @ViewBuilder
    private var bowCard: some View {
        HStack(alignment: .center, spacing: 14) {
            bowIcon
            VStack(alignment: .leading, spacing: 4) {
                Text(bowName)
                    .font(.bpDisplay(17, italic: true, weight: .medium))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
                Text(bowSpec)
                    .font(.bpMono(9.5))
                    .appTracking(0.04, at: 9.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.appInk3)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text("\u{203A}")
                .font(.bpDisplay(18, italic: true, weight: .medium))
                .foregroundStyle(Color.appPond)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.appPaper2)
        .overlay(Rectangle().strokeBorder(Color.appLine, lineWidth: 1))
    }

    @ViewBuilder
    private var bowIcon: some View {
        // 44pt square, 1px pond border, archery glyph in pondDk.
        Image(systemName: "figure.archery")
            .font(.system(size: 24, weight: .medium))
            .foregroundStyle(Color.appPondDk)
            .frame(width: 44, height: 44)
            .overlay(Rectangle().strokeBorder(Color.appPond, lineWidth: 1))
    }

    private var bowName: String {
        selectedBow?.name ?? "No bow selected"
    }

    private var bowSpec: String {
        guard let bow = selectedBow else { return "SELECT A BOW" }
        let bowType = bow.bowType.label.uppercased()
        var parts: [String] = [bowType]
        if let cfg = appState.bowConfigs[bow.id] {
            let dl = UnitFormatting.length(inches: cfg.drawLength, system: unitSystem, digits: 1)
            parts.append("\(dl)DL")
        }
        if let arrow = selectedArrow {
            parts.append(arrow.label.uppercased())
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Distance field

    @ViewBuilder
    private var distanceField: some View {
        VStack(alignment: .leading, spacing: 10) {
            fieldLabel("DISTANCE", hint: distanceHint)
            distanceSegments
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.appLine).frame(height: 1)
        }
    }

    private var distanceHint: String {
        if let d = selectedDistance {
            return "usual · \(d.rawValue)"
        }
        return "optional"
    }

    @ViewBuilder
    private var distanceSegments: some View {
        HStack(spacing: 0) {
            distanceSegment(.twentyYards)
            Rectangle().fill(Color.appLine).frame(width: 1).frame(maxHeight: .infinity)
            distanceSegment(.fiftyMeters)
            Rectangle().fill(Color.appLine).frame(width: 1).frame(maxHeight: .infinity)
            distanceSegment(.seventyMeters)
        }
        .frame(height: 52)
        .overlay(Rectangle().strokeBorder(Color.appLine, lineWidth: 1))
    }

    @ViewBuilder
    private func distanceSegment(_ distance: ShootingDistance) -> some View {
        let selected = selectedDistance == distance
        let parts = splitDistance(distance)
        Button {
            selectedDistance = selected ? nil : distance
        } label: {
            VStack(spacing: 4) {
                Text(parts.num)
                    .font(.bpDisplay(19, italic: true, weight: .medium))
                    .foregroundStyle(selected ? Color.appPaper : Color.appInk2)
                Text(parts.unit)
                    .font(.bpUI(8.5, weight: .semibold))
                    .appTracking(0.18, at: 8.5)
                    .textCase(.uppercase)
                    .foregroundStyle(selected ? Color.appPaper.opacity(0.72) : Color.appInk3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(selected ? Color.appPondDk : Color.appPaper)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("session_distance_row_\(distance.rawValue)")
    }

    private func splitDistance(_ d: ShootingDistance) -> (num: String, unit: String) {
        switch d {
        case .twentyYards:   return ("20", "yd")
        case .fiftyMeters:   return ("50", "m")
        case .seventyMeters: return ("70", "m")
        }
    }

    // MARK: - Target face field

    @ViewBuilder
    private var targetFaceField: some View {
        VStack(alignment: .leading, spacing: 10) {
            fieldLabel("TARGET FACE", hint: "World Archery")
            HStack(spacing: 12) {
                faceTile(.tenRing)
                faceTile(.sixRing)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.appLine).frame(height: 1)
        }
    }

    @ViewBuilder
    private func faceTile(_ face: TargetFaceType) -> some View {
        let selected = selectedFaceType == face
        Button {
            selectedFaceType = face
            userTouchedFace = true
        } label: {
            VStack(spacing: 8) {
                BPTargetFace(face: face == .tenRing ? .tenRing : .sixRing, size: 56)
                    .padding(.top, 4)
                Text(faceName(face))
                    .font(.bpDisplay(11.5, italic: true, weight: .medium))
                    .foregroundStyle(selected ? Color.appPondDk : Color.appInk)
                Text(faceSub(face))
                    .font(.bpMono(8.5))
                    .appTracking(0.04, at: 8.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.appInk3)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background(selected ? Color.appPaper2 : Color.appPaper)
            .overlay(
                Rectangle()
                    .strokeBorder(selected ? Color.appPondDk : Color.appLine,
                                  lineWidth: 1)
            )
            .overlay(
                Group {
                    if selected {
                        Rectangle()
                            .strokeBorder(Color.appPondDk, lineWidth: 1)
                            .padding(1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("session_face_row_\(face.rawValue)")
    }

    private func faceName(_ face: TargetFaceType) -> String {
        switch face {
        case .tenRing: return "10-ring"
        case .sixRing: return "6-ring"
        }
    }

    private func faceSub(_ face: TargetFaceType) -> String {
        switch face {
        case .tenRing: return "122cm · full face"
        case .sixRing: return "inner scoring"
        }
    }

    // MARK: - Intention field

    @ViewBuilder
    private var intentionField: some View {
        VStack(alignment: .leading, spacing: 10) {
            fieldLabel("INTENTION", hint: "optional · one line")
            intentionBox
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var intentionBox: some View {
        HStack(alignment: .top, spacing: 4) {
            Text("\u{201C}") // Left double curly quote
                .font(.bpDisplay(22, italic: true, weight: .medium))
                .foregroundStyle(Color.appPond)
                .baselineOffset(-2)
                .padding(.top, -2)
            ZStack(alignment: .topLeading) {
                if viewModel.intentionNote.isEmpty {
                    Text("Keep the back tension through the click. No rushing the shot on end two.")
                        .font(.bpDisplay(13.5, italic: true, weight: .regular))
                        .foregroundStyle(Color.appInk3)
                        .lineLimit(3)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $viewModel.intentionNote)
                    .font(.bpDisplay(13.5, italic: true, weight: .regular))
                    .foregroundStyle(Color.appInk)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 44)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
        .background(Color.appPaper2)
        .overlay(
            Rectangle()
                .strokeBorder(Color.appLine,
                              style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }

    // MARK: - Begin CTA

    @ViewBuilder
    private var beginCtaBlock: some View {
        VStack(spacing: 10) {
            BPPrimaryButton(
                title: "Begin session",
                subtitle: ctaSubtitle,
                disabled: selectedBow == nil || selectedArrow == nil || isStarting
            ) {
                if isReadOnly { showingPaywall = true }
                else { Task { await startNewSession() } }
            }
            Text("nock up, breathe, and tap when you're on the line.")
                .font(.bpDisplay(11, italic: true, weight: .regular))
                .foregroundStyle(Color.appInk3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 16)
    }

    private var ctaSubtitle: String {
        let distance = selectedDistance?.rawValue.uppercased() ?? "DISTANCE"
        let bow = (selectedBow?.name ?? "BOW").uppercased()
        let face = selectedFaceType == .tenRing ? "10-RING" : "6-RING"
        return "\(distance) · \(bow) · \(face)"
    }

    // MARK: - Generic field label row

    @ViewBuilder
    private func fieldLabel(_ label: String, hint: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.bpUI(9, weight: .semibold))
                .appTracking(0.24, at: 9)
                .textCase(.uppercase)
                .foregroundStyle(Color.appInk3)
            Spacer(minLength: 8)
            Text(hint)
                .font(.bpDisplay(10.5, italic: true, weight: .medium))
                .foregroundStyle(Color.appPond)
        }
    }

    // MARK: - Setup priming

    private func primeSetupState() {
#if DEBUG
        // Snapshot tests inject pre-populated AppState and an in-memory SwiftData
        // store. Calling context.fetch() from within the snapshot render path can
        // crash. When isSnapshotTest is true we skip the store sync and rely
        // solely on the already-populated AppState.
        if !viewModel.isSnapshotTest {
            if let fresh = try? store.fetchBows(), fresh.count != appState.bows.count {
                appState.bows = fresh
            }
            if let fresh = try? store.fetchArrowConfigs(), fresh.count != appState.arrowConfigs.count {
                appState.arrowConfigs = fresh
            }
        }
#else
        if let fresh = try? store.fetchBows(), fresh.count != appState.bows.count {
            appState.bows = fresh
        }
        if let fresh = try? store.fetchArrowConfigs(), fresh.count != appState.arrowConfigs.count {
            appState.arrowConfigs = fresh
        }
#endif
        if selectedBow == nil { selectedBow = appState.bows.first }
        if selectedArrow == nil { selectedArrow = appState.arrowConfigs.first }
        if !userTouchedFace, let bow = selectedBow {
            selectedFaceType = TargetFaceType.defaultFor(bow.bowType)
        }
        if selectedDistance == nil, !lastDistanceRaw.isEmpty {
            selectedDistance = ShootingDistance(rawValue: lastDistanceRaw)
        }
    }

    private func startNewSession() async {
        guard let bow = selectedBow, let arrow = selectedArrow else { return }
        isStarting = true
        let latestConfig: BowConfiguration
        if let live = appState.bowConfigs[bow.id] {
            latestConfig = live
        } else {
            let configs = (try? await APIClient.shared.fetchConfigurations(bowId: bow.id)) ?? []
            latestConfig = configs.sorted { $0.createdAt > $1.createdAt }.first
                ?? BowConfiguration.makeDefault(for: bow)
        }
        let freshArrow = appState.arrowConfigs.first(where: { $0.id == arrow.id }) ?? arrow
        await viewModel.startSession(
            bow: bow,
            bowConfig: latestConfig,
            arrowConfig: freshArrow,
            targetFaceType: selectedFaceType,
            distance: selectedDistance
        )
        isStarting = false
    }

    // MARK: - Active Session Layout (Kenrokuen)

    @ViewBuilder
    private var activeSessionContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                liveHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)
                    .overlay(
                        Rectangle().fill(Color.appLine).frame(height: 1),
                        alignment: .bottom
                    )

                configBanner
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                targetSection
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                if viewModel.isLoading {
                    ProgressView().padding(.bottom, 4)
                }

                recentArrowsStrip
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                runningTotalsRow
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                actionsRow
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                finishBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                Color.clear.frame(height: 20)
            }
        }
        .sheet(isPresented: $showConfigSheet) {
            SessionConfigSheet(appState: appState, viewModel: viewModel)
        }
    }

    // MARK: - Live header

    @ViewBuilder
    private var liveHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                livePulseLabel
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Arrow ")
                        .font(.bpDisplay(32, italic: true, weight: .medium))
                        .foregroundStyle(Color.appInk)
                    Text("\(viewModel.allArrows.count + 1)")
                        .font(.bpDisplay(32, italic: true, weight: .medium))
                        .foregroundStyle(Color.appPondDk)
                }
            }
            Spacer(minLength: 8)
            timerBlock
        }
    }

    @ViewBuilder
    private var livePulseLabel: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.appMaple)
                .frame(width: 6, height: 6)
                .opacity(pulseOpacity)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                           value: pulseOpacity)
            Text("IN SESSION")
                .font(.bpUI(9.5, weight: .semibold))
                .appTracking(0.28, at: 9.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.appPondDk)
        }
    }

    /// Flips between 0.35 and 1.0 every second-tick so the pulsing dot's
    /// animation has a value to latch onto (SwiftUI animates the change).
    private var pulseOpacity: Double {
        Int(now.timeIntervalSince1970) % 2 == 0 ? 0.35 : 1.0
    }

    @ViewBuilder
    private var timerBlock: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(elapsedString)
                .font(.bpDisplay(16, italic: true, weight: .medium))
                .foregroundStyle(Color.appInk)
            Text("ELAPSED")
                .font(.bpMono(10.5))
                .appTracking(0.06, at: 10.5)
                .foregroundStyle(Color.appInk3)
        }
    }

    private var elapsedString: String {
        let start = viewModel.currentSession?.startedAt ?? now
        let sec = Int(now.timeIntervalSince(start))
        let m = sec / 60
        let s = sec % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Config Banner (active)

    @ViewBuilder
    private var configBanner: some View {
        VStack(spacing: 0) {
            if viewModel.hasPendingConfigChange {
                HStack(spacing: 8) {
                    Text("\u{25A0}") // ■
                        .font(.bpDisplay(10, italic: true, weight: .medium))
                        .foregroundStyle(Color.appMaple)
                    Text("Config changed — plot an arrow to confirm new config")
                        .font(.bpDisplay(12, italic: true, weight: .regular))
                        .foregroundStyle(Color.appMaple)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appPaper2)
                .overlay(Rectangle().strokeBorder(Color.appLine, lineWidth: 1))
                .padding(.bottom, 8)
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(bannerPrimary)
                        .font(.bpDisplay(13, italic: true, weight: .medium))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)
                    if let sub = bannerSub {
                        Text(sub)
                            .font(.bpMono(9.5))
                            .appTracking(0.04, at: 9.5)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.appInk3)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                BPEditLink("CHANGE") { showConfigSheet = true }
            }
            .padding(.vertical, 10)
            .overlay(
                Rectangle().fill(Color.appLine).frame(height: 1),
                alignment: .bottom
            )
        }
    }

    private var bannerPrimary: String {
        let distance = viewModel.currentSession?.distance?.rawValue ?? "—"
        let bow = viewModel.selectedBow?.name ?? "—"
        let arrow = (viewModel.pendingArrowConfig ?? viewModel.activeArrowConfig)?.label ?? "—"
        return "\(distance) · \(bow) · \(arrow)"
    }

    private var bannerSub: String? {
        guard let c = viewModel.currentSession?.conditions else { return nil }
        var parts: [String] = []
        if let w = c.windSpeed { parts.append(String(format: "WIND %.0fKT", w)) }
        if let t = c.tempF {
            let tC = (t - 32) * 5 / 9
            parts.append(String(format: "%.0f°C", tC))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Target section

    @ViewBuilder
    private var targetSection: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    let size = min(proxy.size.width, 320)
                    HStack {
                        Spacer()
                        targetFaceWithDots(size: size)
                        Spacer()
                    }
                }
                .frame(height: 320)
            }
            crumbOverlay
                .padding(.top, 4)
            instrOverlay
        }
    }

    @ViewBuilder
    private func targetFaceWithDots(size: CGFloat) -> some View {
        // Hit-testing is preserved via TargetPlotView. The BPTargetFace
        // overlay is strictly visual and sits behind the TargetPlotView.
        let faceType = viewModel.currentSession?.targetFaceType
            ?? (viewModel.selectedBow.map { TargetFaceType.defaultFor($0.bowType) } ?? .sixRing)

        TargetPlotView(
            arrows: viewModel.allArrows,
            onArrowPlotted: { ring, zone, plotX, plotY in
                if isReadOnly { showingPaywall = true }
                else {
                    Task {
                        await viewModel.plotArrow(ring: ring, zone: zone,
                                                  plotX: plotX, plotY: plotY)
                    }
                }
            },
            isEnabled: !viewModel.isLoading,
            arrowDiameterMm: {
                let current = viewModel.pendingArrowConfig ?? viewModel.activeArrowConfig
                let live = appState.arrowConfigs.first(where: { $0.id == current?.id })
                return (live ?? current)?.shaftDiameter?.rawValue ?? 5.0
            }(),
            faceType: faceType
        )
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var crumbOverlay: some View {
        let faceType = viewModel.currentSession?.targetFaceType ?? .sixRing
        VStack(alignment: .leading, spacing: 3) {
            Text("FACE")
                .font(.bpUI(9, weight: .semibold))
                .appTracking(0.20, at: 9)
                .textCase(.uppercase)
                .foregroundStyle(Color.appInk3)
            Text("\(faceName(faceType)) · \(faceSize(faceType))")
                .font(.bpDisplay(10, italic: true, weight: .medium))
                .foregroundStyle(Color.appPondDk)
        }
    }

    private func faceSize(_ face: TargetFaceType) -> String {
        switch face {
        case .tenRing: return "122cm"
        case .sixRing: return "80cm"
        }
    }

    @ViewBuilder
    private var instrOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("tap where the arrow landed.\nlong-press to fine-adjust.")
                    .font(.bpDisplay(11, italic: true, weight: .regular))
                    .foregroundStyle(Color.appInk3)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140, alignment: .trailing)
            }
        }
    }

    // MARK: - Recent arrows strip

    @ViewBuilder
    private var recentArrowsStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("RECENT ARROWS")
                    .font(.bpUI(9, weight: .semibold))
                    .appTracking(0.22, at: 9)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.appInk3)
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(recentAvgString)
                        .font(.bpDisplay(16, italic: true, weight: .medium))
                        .foregroundStyle(Color.appPondDk)
                    Text(" AVG OF LAST \(min(6, viewModel.allArrows.count))")
                        .font(.bpUI(8.5, weight: .semibold))
                        .appTracking(0.12, at: 8.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.appInk3)
                }
            }

            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { idx in
                    recentCell(idx)
                }
            }
        }
        .overlay(Rectangle().fill(Color.appLine).frame(height: 1), alignment: .top)
        .overlay(Rectangle().fill(Color.appLine).frame(height: 1), alignment: .bottom)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func recentCell(_ col: Int) -> some View {
        // Right-to-left: col 5 (last) is the newest arrow; col 0 is oldest of last 6.
        let arrows = viewModel.allArrows
        let startIdx = max(0, arrows.count - 6)
        let cellIdx = startIdx + col
        let arrow: ArrowPlot? = cellIdx < arrows.count ? arrows[cellIdx] : nil
        let isX = (arrow?.ring ?? 0) == 11

        VStack(spacing: 4) {
            Text(arrow.map { valueFor($0.ring) } ?? "—")
                .font(.bpDisplay(20, italic: true, weight: .medium))
                .foregroundStyle(arrow == nil ? Color.appInk3 : (isX ? Color.appPine : Color.appInk))
            Text(arrow == nil ? "—" : "#\(cellIdx + 1)")
                .font(.bpUI(8, weight: .semibold))
                .appTracking(0.16, at: 8)
                .textCase(.uppercase)
                .foregroundStyle(Color.appInk3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(arrow == nil ? Color.appPaper2 : Color.appPaper)
        .overlay(
            Rectangle()
                .strokeBorder(isX ? Color.appPondDk : Color.appLine, lineWidth: 1)
        )
    }

    private func valueFor(_ ring: Int) -> String {
        ring == 11 ? "X" : "\(ring)"
    }

    private var recentAvgString: String {
        let arrows = viewModel.allArrows
        guard !arrows.isEmpty else { return "0.0" }
        let last = arrows.suffix(6)
        let total = last.reduce(0) { $0 + min($1.ring, 10) }
        let avg = Double(total) / Double(last.count)
        return String(format: "%.1f", avg)
    }

    // MARK: - Running totals

    @ViewBuilder
    private var runningTotalsRow: some View {
        HStack(alignment: .top, spacing: 12) {
            totalsPrimary
            Rectangle().fill(Color.appLine2).frame(width: 1, height: 60)
            totalsXs
            Rectangle().fill(Color.appLine2).frame(width: 1, height: 60)
            totalsBest
        }
        .overlay(Rectangle().fill(Color.appLine).frame(height: 1), alignment: .bottom)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var totalsPrimary: some View {
        VStack(alignment: .leading, spacing: 4) {
            BPEyebrow("AVG SO FAR")
            BPBigScore(value: avgSoFarString, size: 28)
            Text("across \(viewModel.allArrows.count) arrow\(viewModel.allArrows.count == 1 ? "" : "s")")
                .font(.bpUI(9))
                .foregroundStyle(Color.appInk3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var totalsXs: some View {
        let xs = viewModel.allArrows.filter { $0.ring == 11 }.count
        let total = viewModel.allArrows.count
        let rate = total > 0 ? Double(xs) / Double(total) * 100 : 0
        VStack(alignment: .leading, spacing: 4) {
            BPEyebrow("XS")
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(xs)")
                    .font(.bpDisplay(24, italic: true, weight: .medium))
                    .foregroundStyle(Color.appInk)
                Text("/\(total)")
                    .font(.bpMono(11))
                    .foregroundStyle(Color.appInk3)
            }
            Text(String(format: "%.0f%% rate", rate))
                .font(.bpUI(9))
                .foregroundStyle(Color.appInk3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var totalsBest: some View {
        let best = bestStreak()
        VStack(alignment: .leading, spacing: 4) {
            BPEyebrow("SESSION BEST")
            Text(best.label)
                .font(.bpDisplay(18, italic: true, weight: .medium))
                .foregroundStyle(Color.appInk)
            Text(best.sub)
                .font(.bpUI(9))
                .foregroundStyle(Color.appInk3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var avgSoFarString: String {
        let arrows = viewModel.allArrows
        guard !arrows.isEmpty else { return "0.0" }
        let total = arrows.reduce(0) { $0 + min($1.ring, 10) }
        let avg = Double(total) / Double(arrows.count)
        return String(format: "%.1f", avg)
    }

    /// Returns a (label, sub) tuple for the best in-session scoring streak.
    /// Best streak = longest run of X's; falls back to longest run of 10+.
    private func bestStreak() -> (label: String, sub: String) {
        let arrows = viewModel.allArrows
        guard !arrows.isEmpty else { return ("—", "no arrows yet") }

        // Find longest X streak.
        var bestX = 0, curX = 0, bestXStart = 0, curXStart = 0
        for (i, a) in arrows.enumerated() {
            if a.ring == 11 {
                if curX == 0 { curXStart = i }
                curX += 1
                if curX > bestX {
                    bestX = curX
                    bestXStart = curXStart
                }
            } else {
                curX = 0
            }
        }
        if bestX >= 2 {
            let end = bestXStart + bestX - 1
            return ("X", "\(bestX) in a row · #\(bestXStart + 1)–\(end + 1)")
        }
        // Fallback — best single ring.
        let bestRing = arrows.map { $0.ring }.max() ?? 0
        return (valueFor(bestRing), "best shot so far")
    }

    // MARK: - Actions row

    @ViewBuilder
    private var actionsRow: some View {
        HStack(spacing: 10) {
            actionButton(glyph: "\u{21B6}", label: "UNDO LAST") {
                viewModel.removeLastArrow()
            }
            actionButton(glyph: "\u{270E}", label: "ADD NOTE") {
                showNotesEditor = true
            }
            finishActionButton
        }
    }

    @ViewBuilder
    private func actionButton(glyph: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(glyph)
                    .font(.bpDisplay(13.5, italic: true, weight: .medium))
                    .foregroundStyle(Color.appInk)
                Text(label)
                    .font(.bpUI(10, weight: .semibold))
                    .appTracking(0.18, at: 10)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.appInk2)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.top, 11)
            .padding(.bottom, 9)
            .background(Color.appPaper2)
            .overlay(Rectangle().strokeBorder(Color.appLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var finishActionButton: some View {
        Button {
            if isReadOnly { showingPaywall = true }
            else { showEndConfirmation = true }
        } label: {
            VStack(spacing: 4) {
                Text("\u{2713} Finish") // ✓
                    .font(.bpDisplay(13.5, italic: true, weight: .medium))
                    .foregroundStyle(Color.appPaper)
                Text("SAVE · SYNC · LOG")
                    .font(.bpUI(10, weight: .semibold))
                    .appTracking(0.18, at: 10)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.appPaper.opacity(0.72))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.top, 11)
            .padding(.bottom, 9)
            .background(Color.appPondDk)
            .overlay(Rectangle().strokeBorder(Color.appPondDk, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isEnding)
    }

    // MARK: - Finish bar

    @ViewBuilder
    private var finishBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                if isReadOnly { showingPaywall = true }
                else { showDiscardConfirmation = true }
            } label: {
                HStack(spacing: 2) {
                    Text("DISCARD")
                        .font(.bpUI(9.5, weight: .semibold))
                        .appTracking(0.20, at: 9.5)
                        .textCase(.uppercase)
                    Text("\u{203A}")
                        .font(.bpDisplay(11, italic: true, weight: .medium))
                }
                .foregroundStyle(Color.appInk3)
            }
            .buttonStyle(.plain)
            .disabled(isDiscarding || isEnding)

            Spacer()

            Text(autosaveLine)
                .font(.bpDisplay(11, italic: true, weight: .regular))
                .foregroundStyle(Color.appInk3)

            Spacer()

            // Right placeholder — preserves centered autosave line.
            Text("")
                .frame(width: 72)
        }
        .overlay(Rectangle().fill(Color.appLine).frame(height: 1), alignment: .top)
        .padding(.top, 14)
    }

    private var autosaveLine: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        let t = f.string(from: now)
        return "autosaved · \(t) · cloud \u{2713}"
    }

    // MARK: - End / Discard Session

    private func endSession() async {
        isEnding = true
        await viewModel.endSession()
        isEnding = false
    }

    private func discardSession() async {
        isDiscarding = true
        await viewModel.cancelSession()
        isDiscarding = false
    }
}

// MARK: - Bow Picker Sheet

private struct BowPickerSheet: View {
    var appState: AppState
    @Binding var selectedBow: Bow?
    @Binding var selectedArrow: ArrowConfiguration?
    @Binding var selectedFaceType: TargetFaceType
    @Binding var userTouchedFace: Bool
    let unitSystem: UnitSystem

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Bow") {
                    if appState.bows.isEmpty {
                        Text("No bows configured. Add one in the Equipment tab.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.bows) { bow in
                            Button {
                                selectedBow = bow
                                if !userTouchedFace {
                                    selectedFaceType = TargetFaceType.defaultFor(bow.bowType)
                                }
                            } label: {
                                pickerRow(title: bow.name,
                                          subtitle: bow.bowType.label,
                                          isSelected: selectedBow?.id == bow.id)
                            }
                        }
                    }
                }

                Section("Arrows") {
                    if appState.arrowConfigs.isEmpty {
                        Text("No arrow configs. Add one in the Equipment tab.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.arrowConfigs) { arrow in
                            Button {
                                selectedArrow = arrow
                            } label: {
                                pickerRow(title: arrow.label,
                                          subtitle: arrow.specSummary(system: unitSystem),
                                          isSelected: selectedArrow?.id == arrow.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Change")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func pickerRow(title: String, subtitle: String, isSelected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body).fontWeight(.semibold)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.appPondDk)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Session Notes Sheet

private struct SessionNotesSheet: View {
    @Binding var notes: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                TextEditor(text: $notes)
                    .font(.bpDisplay(15, italic: true, weight: .regular))
                    .padding(12)
                Spacer()
            }
            .navigationTitle("Session notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - End Row (used by HistoricalSessionsView)
//
// Kept intact for the historical session viewer, which still renders ends
// using the pre-Kenrokuen style. When that surface is redesigned this can
// be folded into the Kenrokuen primitives.

struct EndRow: View {
    var end: SessionEnd?
    var endNumber: Int = 0
    var arrows: [ArrowPlot]
    var isCurrent: Bool
    var onToggleFlier: ((String) -> Void)? = nil

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
                    ForEach(arrows) { arrow in
                        if let onToggleFlier {
                            Button {
                                onToggleFlier(arrow.id)
                            } label: {
                                RingBadge(ring: arrow.ring, excluded: arrow.excluded)
                            }
                            .buttonStyle(.plain)
                        } else {
                            RingBadge(ring: arrow.ring, excluded: arrow.excluded)
                        }
                    }
                }
            }
            .frame(height: 28)
            if isCurrent && onToggleFlier != nil {
                Text("Tap an arrow to flag it as a flier (excluded from analytics).")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
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

// MARK: - Legacy Ring Badge (kept for API continuity if other files use it)

struct RingBadge: View {
    var ring: Int
    var excluded: Bool = false

    var body: some View {
        Text(ring == 11 ? "X" : "\(ring)")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(textColor)
            .frame(width: 24, height: 24)
            .background(bgColor)
            .clipShape(Circle())
            .opacity(excluded ? 0.35 : 1.0)
            .overlay {
                if excluded {
                    Rectangle()
                        .fill(Color.appDanger.opacity(0.85))
                        .frame(width: 28, height: 2)
                        .rotationEffect(.degrees(-45))
                }
            }
    }

    private var bgColor: Color {
        switch ring {
        case 11:    return .appTargetGold
        case 9, 10: return .appTargetYellow
        case 7, 8:  return .appTargetRed
        case 5, 6:  return .appTargetBlue
        default:    return .appTextTertiary
        }
    }

    private var textColor: Color {
        ring >= 9 ? .appTargetInk : .white
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
        startedAt: Date().addingTimeInterval(-1938), endedAt: nil,
        notes: "", feelTags: [], arrowCount: 0,
        targetFaceType: .tenRing,
        distance: .fiftyMeters
    )
    vm.allArrows = [
        ArrowPlot(id: "1", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "a1",
                  ring: 10, zone: .center, shotAt: Date(), excluded: false, notes: nil),
        ArrowPlot(id: "2", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "a1",
                  ring: 9, zone: .ne, shotAt: Date(), excluded: false, notes: nil),
        ArrowPlot(id: "3", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "a1",
                  ring: 11, zone: .center, shotAt: Date(), excluded: false, notes: nil),
        ArrowPlot(id: "4", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "a1",
                  ring: 10, zone: .w, shotAt: Date(), excluded: false, notes: nil),
        ArrowPlot(id: "5", sessionId: "s1", bowConfigId: "bc1", arrowConfigId: "a1",
                  ring: 11, zone: .center, shotAt: Date(), excluded: false, notes: nil),
    ]

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
