import SwiftUI

// MARK: - AnalyticsView (Kenrokuen)
//
// Rewrite of the Analytics tab against the Wave-2 redesign. The layout
// follows bowpress-design-system/project/explorations/analytics-japanese.html
// top to bottom; everything lives in one ScrollView so the rhythm of
// hairline-separated sections reads as a single page.

struct AnalyticsView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocalStore.self) private var store
    @State private var viewModel = AnalyticsViewModel()
    @State private var highlightedSuggestionId: String?
    @State private var filtersSheetPresented = false

    #if DEBUG
    /// Test-only initialiser — injects a pre-populated `AnalyticsViewModel` so
    /// snapshot tests can render specific states without hitting the network.
    /// Passing `nil` (the default) is equivalent to the synthesised no-arg init.
    /// `@MainActor` is required because `AnalyticsViewModel.init()` is
    /// main-actor-isolated; `nil` is used as the default to avoid evaluating
    /// that call in a nonisolated default-parameter position.
    @MainActor
    init(testViewModel: AnalyticsViewModel? = nil) {
        _viewModel = State(initialValue: testViewModel ?? AnalyticsViewModel())
    }
    #endif

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.overview == nil {
                loadingView
            } else {
                mainContent
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.appPaper.ignoresSafeArea())
        .task {
            await initialLoad()
        }
        .onChange(of: appState.analyticsRefreshNonce) { _, _ in
            Task { await viewModel.refresh() }
        }
        .sheet(isPresented: $filtersSheetPresented) {
            FiltersSheet(viewModel: viewModel, store: store, appState: appState)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    // The BPNavHeader owns its own 16pt horizontal padding,
                    // so it intentionally sits un-padded here — the hairline
                    // runs edge-to-edge below the title. Everything else
                    // below gets the 18pt screen margin.
                    filterSummary
                        .padding(.horizontal, 18)
                        .padding(.top, 10)

                    if let errorMessage = viewModel.error {
                        errorBanner(message: errorMessage)
                            .padding(.horizontal, 18)
                            .padding(.top, 12)
                    }

                    if let overview = viewModel.overview, overview.sessionCount > 0 {
                        body(overview: overview)
                            .padding(.horizontal, 18)
                    } else if !viewModel.isLoading {
                        emptyStateView
                            .padding(.horizontal, 18)
                            .padding(.top, 20)
                    }

                    if viewModel.isLoading && viewModel.overview != nil {
                        HStack {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                                .tint(.appPondDk)
                            Text("Refreshing…")
                                .font(.bpUI(11))
                                .foregroundStyle(Color.appInk3)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                }
                .padding(.bottom, 32)
            }
            .refreshable { await viewModel.refresh() }
            .onChange(of: appState.pendingAnalyticsNavigation) { _, intent in
                scrollToIntent(intent, proxy: proxy)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        BPNavHeader(eyebrow: "Bowpress", title: "Analytics") {
            headerMeta
        }
    }

    private var headerMeta: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(dateYmd)
                .foregroundStyle(Color.appInk3)
            Text(dayOfWeek)
                .font(.bpMono(10, weight: .medium))
                .foregroundStyle(Color.appInk)
            let count = viewModel.overview?.sessionCount ?? 0
            (
                Text("session no. ")
                    .foregroundStyle(Color.appInk3)
                + Text(String(format: "%03d", max(count, 0)))
                    .font(.bpMono(10, weight: .medium))
                    .foregroundStyle(Color.appInk)
            )
        }
        .font(.bpMono(10))
    }

    private var dateYmd: String {
        let d = Date.now
        let f = DateFormatter()
        f.dateFormat = "yyyy · MM · dd"
        return f.string(from: d)
    }

    private var dayOfWeek: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: Date.now).lowercased()
    }

    // MARK: - Filter summary bar

    private var filterSummary: some View {
        BPFilterSummary(
            summary: "\(bowLabel) · \(distanceLabel) · \(viewModel.selectedPeriod.label)",
            subtitle: "tap to change filters",
            onEdit: { filtersSheetPresented = true }
        )
    }

    private var bowLabel: String { viewModel.selectedBowType?.label ?? "All bows" }
    private var distanceLabel: String { viewModel.selectedDistance?.label ?? "All distances" }

    // MARK: - Body below header + filter

    @ViewBuilder
    private func body(overview: AnalyticsOverview) -> some View {
        statGrid(overview: overview)
            .padding(.top, 4)

        if let comparison = viewModel.comparison, comparison.previous.sessionCount > 0 {
            compareStrip(comparison: comparison)
        }

        timeline(overview: overview)

        impactMap(overview: overview)

        trendAnalysis()

        parameterDrift()

        suggestionsLedger()

        footnotes(overview: overview)

        colophon
            .padding(.top, 8)
    }

    // MARK: - 3-col stat grid

    @ViewBuilder
    private func statGrid(overview: AnalyticsOverview) -> some View {
        HStack(alignment: .top, spacing: 14) {
            statCellAverage(overview: overview)
            verticalRule
            statCellXRate(overview: overview)
            verticalRule
            statCellGroup(overview: overview)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.appLine).frame(height: 1)
        }
    }

    private var verticalRule: some View {
        Rectangle().fill(Color.appLine2).frame(width: 1)
    }

    @ViewBuilder
    private func statCellAverage(overview: AnalyticsOverview) -> some View {
        BPStatGridCell(label: "Average", sub: "per arrow · out of 11") {
            BPBigScore(value: formatted(overview.avgArrowScore), size: 56)
        } tick: {
            sparkTicks(points: overview.sparkline?.map(\.avg) ?? [])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 9 thin bars mapping to the last 9 sparkline points. The tallest one
    /// gets the `appPondDk` accent in the reference — we apply the same to
    /// whichever bar is the current max.
    private func sparkTicks(points: [Double]) -> some View {
        let trimmed = Array(points.suffix(9))
        let hi = trimmed.max() ?? 11
        let lo = trimmed.min() ?? 8
        let span = max(hi - lo, 0.5)
        return HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(trimmed.enumerated()), id: \.offset) { idx, v in
                let norm = (v - lo) / span
                let heightFraction = 0.35 + norm * 0.6 // keep bars visible even at the floor
                let isMax = v == hi && idx == trimmed.lastIndex(of: hi)
                Rectangle()
                    .fill(isMax ? Color.appPondDk : Color.appPondLt)
                    .frame(width: 3, height: 18 * heightFraction)
            }
        }
        .frame(height: 18, alignment: .bottom)
    }

    @ViewBuilder
    private func statCellXRate(overview: AnalyticsOverview) -> some View {
        let pct = Int(overview.xPercentage.rounded())
        let prevPct = viewModel.comparison?.previous.xPercentage
        VStack(alignment: .leading, spacing: 6) {
            BPEyebrow("X rate")
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(pct)")
                    .font(.bpDisplay(28, italic: true, weight: .medium))
                    .foregroundStyle(Color.appPondDk)
                Text("%")
                    .font(.bpDisplay(17, italic: true, weight: .medium))
                    .foregroundStyle(Color.appPondDk)
            }
            Text(prevPct.map { "prev · \(Int($0.rounded()))%" } ?? "prev · —")
                .font(.bpUI(10))
                .foregroundStyle(Color.appInk3)
            Text("\(overview.sessionCount)")
                .font(.bpDisplay(17, italic: true, weight: .medium))
                .foregroundStyle(Color.appInk)
                .padding(.top, 4)
            Text("sessions")
                .font(.bpUI(10))
                .foregroundStyle(Color.appInk3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func statCellGroup(overview: AnalyticsOverview) -> some View {
        let sigma = overview.groupSigma ?? 0
        let sigmaText = sigma == 0 ? "—" : String(format: "%.1f", sigma)
        let distanceText = viewModel.selectedDistance?.label ?? (distanceLabel == "All distances" ? "mixed" : distanceLabel)
        let arrows = overview.datasetSummary?.arrows ?? estimatedArrows(overview: overview)
        VStack(alignment: .leading, spacing: 6) {
            BPEyebrow("Group \u{2205}")
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(sigmaText)
                    .font(.bpDisplay(28, italic: true, weight: .medium))
                    .foregroundStyle(Color.appPondDk)
                Text("\u{2033}")
                    .font(.bpDisplay(15, italic: true, weight: .medium))
                    .foregroundStyle(Color.appPondDk)
            }
            Text("at \(distanceText)")
                .font(.bpUI(10))
                .foregroundStyle(Color.appInk3)
            Text("\(arrows)")
                .font(.bpDisplay(17, italic: true, weight: .medium))
                .foregroundStyle(Color.appInk)
                .padding(.top, 4)
            Text("arrows logged")
                .font(.bpUI(10))
                .foregroundStyle(Color.appInk3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func estimatedArrows(overview: AnalyticsOverview) -> Int {
        // Fallback when the server hasn't yet populated `datasetSummary`.
        // 18 arrows/session is the WA outdoor end standard.
        max(overview.sessionCount * 18, 0)
    }

    // MARK: - Prev → now compare strip

    @ViewBuilder
    private func compareStrip(comparison: PeriodComparison) -> some View {
        let delta = comparison.current.avgArrowScore - comparison.previous.avgArrowScore
        HStack(alignment: .center, spacing: 10) {
            // Previous column
            VStack(alignment: .leading, spacing: 3) {
                BPEyebrow("Prev \(prettyPeriod)")
                Text(formatted(comparison.previous.avgArrowScore))
                    .font(.bpDisplay(20, italic: true, weight: .medium))
                    .foregroundStyle(Color.appInk)
                Text(
                    "\(Int(comparison.previous.xPercentage.rounded()))% X · \(comparison.previous.sessionCount) sessions"
                )
                .font(.bpMono(9.5))
                .foregroundStyle(Color.appInk3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Middle arrow
            Text("\u{2192}")
                .font(.bpDisplay(22, italic: true, weight: .medium))
                .foregroundStyle(Color.appMoss)

            // Current column
            VStack(alignment: .leading, spacing: 3) {
                BPEyebrow("This \(prettyPeriod)")
                Text(formatted(comparison.current.avgArrowScore))
                    .font(.bpDisplay(20, italic: true, weight: .medium))
                    .foregroundStyle(Color.appPondDk)
                HStack(spacing: 6) {
                    Text("\(Int(comparison.current.xPercentage.rounded()))% X · \(comparison.current.sessionCount) sessions")
                        .font(.bpMono(9.5))
                        .foregroundStyle(Color.appInk3)
                    if abs(delta) >= 0.05 {
                        Text((delta > 0 ? "+" : "") + String(format: "%.1f", delta))
                            .font(.bpMono(9.5, weight: .medium))
                            .foregroundStyle(delta > 0 ? Color.appPine : Color.appMaple)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.appLine).frame(height: 1)
        }
    }

    private var prettyPeriod: String {
        switch viewModel.selectedPeriod {
        case .threeDays:   return "3 days"
        case .week:        return "week"
        case .twoWeeks:    return "2 weeks"
        case .month:       return "month"
        case .threeMonths: return "3 months"
        case .sixMonths:   return "6 months"
        case .year:        return "year"
        }
    }

    // MARK: - Score timeline

    @ViewBuilder
    private func timeline(overview: AnalyticsOverview) -> some View {
        let points = overview.sparkline ?? []
        let avgs = points.map(\.avg)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                BPSectionTitle("Score timeline")
                Spacer(minLength: 8)
                if !avgs.isEmpty {
                    let lo = viewModel.timeline?.range.min ?? (avgs.min() ?? 0)
                    let hi = viewModel.timeline?.range.max ?? (avgs.max() ?? 0)
                    let sigma = viewModel.timeline?.range.sigma ?? computedSigma(avgs)
                    Text("range \(formatted(lo))—\(formatted(hi)) · σ \(String(format: "%.2f", sigma))")
                        .font(.bpMono(9.5))
                        .foregroundStyle(Color.appInk3)
                }
            }
            if !avgs.isEmpty {
                ZStack(alignment: .topLeading) {
                    BPSparkline(points: avgs, height: 86)
                    // Axis labels at top / mid / bottom.
                    VStack(alignment: .leading, spacing: 0) {
                        axisLabel(value: avgs.max() ?? 0)
                        Spacer()
                        axisLabel(value: ((avgs.max() ?? 0) + (avgs.min() ?? 0)) / 2)
                        Spacer()
                        axisLabel(value: avgs.min() ?? 0)
                    }
                    .frame(height: 86, alignment: .leading)
                }
            } else {
                Text("no session data yet")
                    .font(.bpUI(11))
                    .foregroundStyle(Color.appInk3)
                    .padding(.vertical, 14)
            }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.appLine).frame(height: 1)
        }
    }

    private func axisLabel(value: Double) -> some View {
        Text(formatted(value))
            .font(.bpMono(9))
            .foregroundStyle(Color.appInk3)
    }

    private func computedSigma(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let v = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(v)
    }

    // MARK: - Impact map

    @ViewBuilder
    private func impactMap(overview: AnalyticsOverview) -> some View {
        let distanceText = viewModel.selectedDistance?.label ?? "all distances"
        let bowTypeText = viewModel.selectedBowType?.label.lowercased() ?? "all bows"
        VStack(alignment: .leading, spacing: 8) {
            BPSectionTitle("Impact map", aside: "\(distanceText) · \(bowTypeText)")
            Text("centroid of grouping · this week vs. previous · 1 ring = 1 point")
                .font(.bpUI(10.5))
                .foregroundStyle(Color.appInk3)

            HStack(alignment: .center, spacing: 14) {
                // Target face + overlay
                let face: BPTargetFace<ImpactMapOverlay>.FaceType = {
                    if viewModel.selectedDistance == .twentyYards { return .sixRing }
                    return .tenRing
                }()
                BPTargetFace(face: face, size: 200, showCrosshair: true) {
                    ImpactMapOverlay(
                        size: 200,
                        previous: viewModel.comparison?.previous,
                        current: viewModel.comparison?.current,
                        shift: viewModel.comparison?.shift
                    )
                }
                .frame(width: 200, height: 200)

                impactLegend()
                    .frame(width: 130)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.appLine).frame(height: 1)
        }
    }

    @ViewBuilder
    private func impactLegend() -> some View {
        let prev = viewModel.comparison?.previous
        let cur = viewModel.comparison?.current
        let shift = viewModel.comparison?.shift
        VStack(alignment: .leading, spacing: 6) {
            legendRow(
                color: nil,
                borderColor: .appInk2,
                name: "Previous",
                stat: shortDateRange(slice: prev, fallback: "—")
            )
            legendRow(
                color: .appMaple,
                borderColor: nil,
                name: "This week",
                stat: shortDateRange(slice: cur, fallback: "—")
            )
            BPEyebrow("Shift")
                .padding(.top, 4)
            Text(shift.map { shiftLine(for: $0) } ?? "not enough data")
                .font(.bpDisplay(13, italic: true, weight: .medium))
                .foregroundStyle(Color.appPine)
            if let shift, !shift.description.isEmpty {
                Text(shift.description)
                    .font(.bpMono(9))
                    .foregroundStyle(Color.appInk3)
            }
        }
    }

    private func shiftLine(for shift: ShiftVector) -> String {
        let dx = shift.dxMm
        let dy = shift.dyMm
        let dxPart = dx == 0 ? "0" : String(format: "%+.0f", dx)
        let dyPart = dy == 0 ? "0" : String(format: "%+.0f", dy)
        return "\(dxPart), \(dyPart) mm"
    }

    private func shortDateRange(slice: PeriodSlice?, fallback: String) -> String {
        guard let slice else { return fallback }
        let arrows = slice.plots.count
        return "\(slice.sessionCount) sess · \(arrows) arr"
    }

    @ViewBuilder
    private func legendRow(color: Color?, borderColor: Color?, name: String, stat: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(color ?? Color.appPaper)
                .overlay(
                    Circle().stroke(borderColor ?? .clear, lineWidth: borderColor == nil ? 0 : 1.2)
                )
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.bpDisplay(12.5, italic: true, weight: .medium))
                    .foregroundStyle(Color.appInk)
                Text(stat)
                    .font(.bpMono(9.5))
                    .foregroundStyle(Color.appInk3)
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.appLine2).frame(height: 1)
        }
    }

    // MARK: - Trend analysis

    @ViewBuilder
    private func trendAnalysis() -> some View {
        let findings = viewModel.trends?.findings ?? []
        let arrows = viewModel.overview?.datasetSummary?.arrows ?? estimatedArrows(overview: viewModel.overview ?? AnalyticsOverview(period: viewModel.selectedPeriod, sessionCount: 0, avgArrowScore: 0, xPercentage: 0, suggestions: []))
        VStack(alignment: .leading, spacing: 8) {
            BPSectionTitle("Trend analysis", aside: findings.isEmpty ? nil : "\(findings.count) findings")
            Text("insight from the last \(arrows) arrows · ranked by actionability")
                .font(.bpUI(10.5))
                .foregroundStyle(Color.appInk3)

            if findings.isEmpty {
                Text("not enough data yet")
                    .font(.bpUI(11))
                    .foregroundStyle(Color.appInk3)
                    .padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(findings) { finding in
                        TrendLedgerRow(finding: finding)
                        if finding.id != findings.last?.id {
                            Rectangle().fill(Color.appLine2).frame(height: 1)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 14)
    }

    // MARK: - Parameter drift

    @ViewBuilder
    private func parameterDrift() -> some View {
        let rows = viewModel.drift?.rows ?? []
        VStack(alignment: .leading, spacing: 8) {
            BPSectionTitle("Parameter drift", aside: rows.isEmpty ? nil : "\(rows.count) tracked")
            Text("setup values across the period · tap for history")
                .font(.bpUI(10.5))
                .foregroundStyle(Color.appInk3)

            if rows.isEmpty {
                Text("not enough data yet")
                    .font(.bpUI(11))
                    .foregroundStyle(Color.appInk3)
                    .padding(.vertical, 12)
            } else {
                driftTable(rows: rows)
            }
        }
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func driftTable(rows: [DriftRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            driftHeader
            Rectangle().fill(Color.appLine).frame(height: 1)
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                driftRow(row: row)
                if idx < rows.count - 1 {
                    Rectangle().fill(Color.appLine2).frame(height: 1)
                }
            }
        }
    }

    private var driftHeader: some View {
        HStack(spacing: 0) {
            driftHeaderCell("Parameter", align: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            driftHeaderCell("Before", align: .trailing).frame(width: 64)
            driftHeaderCell("Now", align: .trailing).frame(width: 64)
            driftHeaderCell("Δ", align: .trailing).frame(width: 64)
            driftHeaderCell("n", align: .trailing).frame(width: 28)
        }
        .padding(.vertical, 6)
    }

    private func driftHeaderCell(_ text: String, align: HorizontalAlignment) -> some View {
        Text(text.uppercased())
            .font(.bpUI(8.5, weight: .semibold))
            .tracking(8.5 * 0.2)
            .foregroundStyle(Color.appInk3)
            .frame(maxWidth: .infinity, alignment: align == .leading ? .leading : .trailing)
    }

    @ViewBuilder
    private func driftRow(row: DriftRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(row.label)
                .font(.bpDisplay(13.5, italic: true, weight: .medium))
                .foregroundStyle(Color.appInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            driftValueCell(row.before ?? "—")
                .frame(width: 64, alignment: .trailing)
            driftValueCell(row.now ?? "—")
                .frame(width: 64, alignment: .trailing)
            driftDeltaCell(row: row)
                .frame(width: 64, alignment: .trailing)
            Text("\(row.n)")
                .font(.bpMono(10))
                .foregroundStyle(Color.appInk3)
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.vertical, 9)
    }

    private func driftValueCell(_ text: String) -> some View {
        Text(text)
            .font(.bpDisplay(12.5, italic: true, weight: .medium))
            .foregroundStyle(Color.appInk)
    }

    @ViewBuilder
    private func driftDeltaCell(row: DriftRow) -> some View {
        let text = row.delta ?? "—"
        let fg: Color = {
            switch row.deltaTone {
            case .up:   return .appPine
            case .down: return .appMaple
            case .flat: return .appInk3
            }
        }()
        let bg: Color = {
            switch row.deltaTone {
            case .up:   return Color.appPine.opacity(0.16)
            case .down: return Color.appMaple.opacity(0.12)
            case .flat: return .clear
            }
        }()
        Text(text)
            .font(.bpMono(10))
            .foregroundStyle(fg)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(bg)
    }

    // MARK: - Suggestions ledger

    @ViewBuilder
    private func suggestionsLedger() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BPSectionTitle(
                "Suggested adjustments",
                aside: viewModel.suggestions.isEmpty ? nil : "\(viewModel.suggestions.count) ranked"
            )
            Text("by confidence · swipe left on a card to dismiss")
                .font(.bpUI(10.5))
                .foregroundStyle(Color.appInk3)

            if viewModel.suggestions.isEmpty {
                Text("no suggestions yet")
                    .font(.bpUI(11))
                    .foregroundStyle(Color.appInk3)
                    .padding(.vertical, 12)
            } else {
                let ordered = orderedSuggestions()
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { idx, suggestion in
                        SwipeableLedgerRow(
                            suggestion: suggestion,
                            index: idx + 1,
                            onTapped: { Task { await viewModel.markRead(suggestion) } },
                            onDismiss: { Task { await viewModel.dismiss(suggestion) } }
                        )
                        .id(suggestion.id)
                        .overlay {
                            if suggestion.id == highlightedSuggestionId {
                                Rectangle()
                                    .strokeBorder(Color.appPondDk, lineWidth: 2)
                                    .animation(.easeInOut(duration: 0.3), value: highlightedSuggestionId)
                            }
                        }
                        if idx < ordered.count - 1 {
                            Rectangle().fill(Color.appLine2).frame(height: 1)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 14)
    }

    private func orderedSuggestions() -> [AnalyticsSuggestion] {
        viewModel.suggestions.sorted { lhs, rhs in
            if lhs.wasApplied != rhs.wasApplied { return !lhs.wasApplied }
            return lhs.confidence > rhs.confidence
        }
    }

    // MARK: - Footnotes grid

    @ViewBuilder
    private func footnotes(overview: AnalyticsOverview) -> some View {
        let ds = overview.datasetSummary
        let bow = appState.bows.first
        let arrow = appState.arrowConfigs.first
        let arrowLabel = ds?.arrowLabel ?? arrow.map { "\($0.label) \(String(format: "%.1f\"", $0.length))" } ?? "—"
        let bowLabel = ds?.bowLabel ?? bow.map { "\($0.name) · \($0.bowType.label.lowercased())" } ?? "—"
        let arrows = ds?.arrows ?? estimatedArrows(overview: overview)
        let sinceText: String = {
            if let d = ds?.sinceDate { return formatYmd(d) }
            return formatYmd(Date.now.addingTimeInterval(-86_400 * 3))
        }()

        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Color.appLine).frame(height: 1)
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                alignment: .leading,
                spacing: 6
            ) {
                footnote(key: "arrow set", value: arrowLabel)
                footnote(key: "updated", value: "just now")
                footnote(key: "bow", value: bowLabel)
                footnote(key: "sync", value: "\u{2713} cloud")
                footnote(key: "dataset", value: "\(arrows) arrows")
                footnote(key: "since", value: sinceText)
            }
            .padding(.top, 12)
        }
        .padding(.top, 14)
    }

    private func footnote(key: String, value: String) -> some View {
        (
            Text(key).font(.bpMono(9.5, weight: .medium)).foregroundStyle(Color.appInk)
            + Text(" · ").foregroundStyle(Color.appInk3)
            + Text(value).foregroundStyle(Color.appInk3)
        )
        .font(.bpMono(9.5))
    }

    private func formatYmd(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy · MM · dd"
        return f.string(from: d)
    }

    // MARK: - Colophon

    private var colophon: some View {
        HStack(spacing: 7) {
            Text("tune smarter")
            Rectangle().fill(Color.appPond).frame(width: 5, height: 5)
            Text("shoot better")
        }
        .font(.bpDisplay(11, italic: true))
        .foregroundStyle(Color.appInk3)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 16)
    }

    // MARK: - Helpers

    private func formatted(_ v: Double) -> String {
        if v == 0 { return "—" }
        if v >= 10 { return String(format: "%.1f", v) }
        return String(format: "%.1f", v)
    }

    private func scrollToIntent(_ intent: SuggestionNavigationIntent?, proxy: ScrollViewProxy) {
        guard case .suggestion(let id, _) = intent else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            proxy.scrollTo(id, anchor: .top)
        }
        highlightedSuggestionId = id
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            await MainActor.run {
                highlightedSuggestionId = nil
                appState.pendingAnalyticsNavigation = nil
            }
        }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 10) {
            BPEyebrow("Not enough data")
            Text("Log at least one session to unlock analytics.")
                .font(.bpDisplay(18, italic: true, weight: .medium))
                .foregroundStyle(Color.appInk)
            Text("Arrows inform centroids, sigmas, and tuning suggestions — six or more is usually enough for the first picture to form.")
                .font(.bpUI(11.5))
                .foregroundStyle(Color.appInk2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Loading view

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(.appPondDk)
            Text("Loading analytics…")
                .font(.bpUI(11, weight: .semibold))
                .foregroundStyle(Color.appInk3)
                .padding(.top, 10)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.appPaper)
    }

    // MARK: - Error banner

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle().fill(Color.appMaple).frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                BPEyebrow("Analytics error", tone: .maple)
                Text(message)
                    .font(.bpUI(11.5))
                    .foregroundStyle(Color.appInk2)
                    .lineLimit(3)
                Button("Retry") { Task { await viewModel.refresh() } }
                    .font(.bpUI(10.5, weight: .semibold))
                    .tracking(10.5 * 0.18)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.appPondDk)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .overlay(Rectangle().strokeBorder(Color.appLine, lineWidth: 1))
        .background(Color.appPaper2)
    }

    // MARK: - Initial load

    private func initialLoad() async {
        guard viewModel.overview == nil else { return }
        viewModel.configure(store: store, appState: appState)
        await viewModel.load(period: viewModel.selectedPeriod)
    }
}

// MARK: - ImpactMapOverlay
//
// Renders the impact-map's dynamic layer: prev/current centroid dots, the
// prev dispersion ellipse (stone dashed), current dispersion ellipse (maple
// solid), individual arrow dots, and the moss shift arrow prev → now.
//
// Coordinates are normalized face-space (roughly -1...1). The target face
// itself draws from a ZStack of centered circles, so the overlay sits in a
// container the same `size` as the face. Local coords: (0,0) = center,
// +x right, +y up (flipped to SwiftUI's +y-down when rendered).

private struct ImpactMapOverlay: View {
    let size: CGFloat
    let previous: PeriodSlice?
    let current: PeriodSlice?
    let shift: ShiftVector?

    private func px(_ x: Double) -> CGFloat {
        // Normalized -1...1 → 0...size (CSS coords have center at size/2).
        return size / 2 + CGFloat(x) * (size / 2)
    }

    private func py(_ y: Double) -> CGFloat {
        // Normalized (physical +y = "up") → SwiftUI's y-down screen coords.
        return size / 2 - CGFloat(y) * (size / 2)
    }

    var body: some View {
        ZStack {
            // Previous dispersion ellipse (stone dashed outline).
            if let prev = previous, let sigma = prev.sigma, let c = prev.centroid {
                Ellipse()
                    .stroke(
                        Color.appPaper,
                        style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                    )
                    .frame(width: size * CGFloat(sigma.major), height: size * CGFloat(sigma.minor))
                    .rotationEffect(.degrees(sigma.rotationDeg))
                    .opacity(0.8)
                    .position(x: px(c.x), y: py(c.y))
            }

            // Previous arrow dots (light cream with ring).
            if let plots = previous?.plots {
                ForEach(arrayIndices(plots, max: 18), id: \.self) { i in
                    let pt = plots[i]
                    if let (x, y) = coord(pt) {
                        Circle()
                            .fill(Color.appPaper.opacity(0.6))
                            .frame(width: 3.2, height: 3.2)
                            .position(x: px(x), y: py(y))
                    }
                }
            }

            // Previous centroid — hollow stone.
            if let c = previous?.centroid {
                Circle()
                    .fill(Color.appPaper)
                    .overlay(Circle().stroke(Color.appInk2, lineWidth: 1.2))
                    .frame(width: 6.8, height: 6.8)
                    .position(x: px(c.x), y: py(c.y))
            }

            // Current dispersion ellipse (maple solid outline).
            if let cur = current, let sigma = cur.sigma, let c = cur.centroid {
                Ellipse()
                    .stroke(Color.appMaple, lineWidth: 1)
                    .frame(width: size * CGFloat(sigma.major), height: size * CGFloat(sigma.minor))
                    .rotationEffect(.degrees(sigma.rotationDeg))
                    .position(x: px(c.x), y: py(c.y))
            }

            // Current arrow dots (maple).
            if let plots = current?.plots {
                ForEach(arrayIndices(plots, max: 18), id: \.self) { i in
                    let pt = plots[i]
                    if let (x, y) = coord(pt) {
                        Circle()
                            .fill(Color.appMaple.opacity(0.95))
                            .frame(width: 3.2, height: 3.2)
                            .position(x: px(x), y: py(y))
                    }
                }
            }

            // Current centroid — filled maple with paper ring.
            if let c = current?.centroid {
                Circle()
                    .fill(Color.appMaple)
                    .overlay(Circle().stroke(Color.appPaper, lineWidth: 1.2))
                    .frame(width: 7.2, height: 7.2)
                    .position(x: px(c.x), y: py(c.y))
            }

            // Moss shift arrow from prev → current.
            if let prev = previous?.centroid, let cur = current?.centroid {
                ShiftArrow(
                    from: CGPoint(x: px(prev.x), y: py(prev.y)),
                    to: CGPoint(x: px(cur.x), y: py(cur.y))
                )
                .stroke(Color.appMoss, style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
                .overlay(
                    ShiftArrowHead(
                        tip: CGPoint(x: px(cur.x), y: py(cur.y)),
                        from: CGPoint(x: px(prev.x), y: py(prev.y))
                    )
                    .fill(Color.appMoss)
                )
            }
        }
        .frame(width: size, height: size)
    }

    /// Returns up to `max` plot indices, preferring plots that actually carry
    /// plotX / plotY values (the rest are filtered out by `coord`).
    private func arrayIndices(_ plots: [ArrowPlot], max: Int) -> [Int] {
        Array(plots.prefix(max).indices)
    }

    /// Resolves an ArrowPlot's normalized (x, y) on the face; nil when the
    /// plot is legacy data that only stored ring + zone.
    private func coord(_ plot: ArrowPlot) -> (Double, Double)? {
        if let x = plot.plotX, let y = plot.plotY { return (x, y) }
        return nil
    }
}

private struct ShiftArrow: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: from)
        p.addLine(to: to)
        return p
    }
}

private struct ShiftArrowHead: Shape {
    let tip: CGPoint
    let from: CGPoint

    func path(in rect: CGRect) -> Path {
        let dx = tip.x - from.x
        let dy = tip.y - from.y
        let len = max(sqrt(dx * dx + dy * dy), 0.001)
        let ux = dx / len
        let uy = dy / len
        let size: CGFloat = 5
        // Perpendicular
        let px = -uy
        let py = ux
        let base = CGPoint(x: tip.x - ux * size, y: tip.y - uy * size)
        let left = CGPoint(x: base.x + px * (size * 0.55), y: base.y + py * (size * 0.55))
        let right = CGPoint(x: base.x - px * (size * 0.55), y: base.y - py * (size * 0.55))
        var p = Path()
        p.move(to: tip)
        p.addLine(to: left)
        p.addLine(to: right)
        p.closeSubpath()
        return p
    }
}

// MARK: - TrendLedgerRow
//
// One row in the Trend analysis ledger. The title can embed a colored
// JetBrains Mono metric tag; the body and cues round out the explanation,
// and a right-hand BPStamp carries the Gain/Watch/Hold badge.

private struct TrendLedgerRow: View {
    let finding: TrendFinding

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(roman(finding.index) + ".")
                .font(.bpDisplay(14, italic: true, weight: .medium))
                .foregroundStyle(Color.appPond)
                .tracking(14 * 0.02)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                titleLine(finding: finding)
                Text(finding.body)
                    .font(.bpUI(11.5))
                    .foregroundStyle(Color.appInk2)
                    .fixedSize(horizontal: false, vertical: true)
                if let cues = finding.cues, !cues.isEmpty {
                    cueLine(cues)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            BPStamp(finding.badge.label, tone: finding.badge.stampTone)
        }
        .padding(.vertical, 14)
    }

    /// The title carries an inline mono metric tag. We render it as a HStack
    /// because SwiftUI's `Text` concatenation doesn't support per-segment
    /// tracking the way CSS does.
    @ViewBuilder
    private func titleLine(finding: TrendFinding) -> some View {
        let tone: Color = {
            switch finding.metric.tone {
            case .positive: return .appPine
            case .negative: return .appMaple
            case .neutral:  return .appPondDk
            }
        }()
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(finding.title)
                .font(.bpDisplay(15, italic: true, weight: .medium))
                .foregroundStyle(Color.appInk)
                .fixedSize(horizontal: false, vertical: true)
            Text(finding.metric.text)
                .font(.bpMono(12, weight: .medium))
                .foregroundStyle(tone)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Cues are rendered as a single mono line; markdown-style **bold**
    /// spans get bumped to appInk2 so the terms visibly pop.
    @ViewBuilder
    private func cueLine(_ raw: String) -> some View {
        let segments = parseBold(raw)
        segments.reduce(Text("")) { acc, seg in
            acc + Text(seg.text)
                .font(.bpMono(9.5, weight: seg.bold ? .medium : .regular))
                .foregroundStyle(seg.bold ? Color.appInk2 : Color.appInk3)
        }
        .tracking(9.5 * 0.04)
    }

    private struct Seg { let text: String; let bold: Bool }

    /// Tiny markdown parser — splits `text **bold** more` into alternating
    /// plain + bold fragments. No escapes; if an unmatched `**` is hit we
    /// leave the rest plain.
    private func parseBold(_ s: String) -> [Seg] {
        var out: [Seg] = []
        var remaining = Substring(s)
        while let range = remaining.range(of: "**") {
            let lead = remaining[..<range.lowerBound]
            if !lead.isEmpty { out.append(Seg(text: String(lead), bold: false)) }
            let afterOpen = remaining[range.upperBound...]
            if let close = afterOpen.range(of: "**") {
                let boldPart = afterOpen[..<close.lowerBound]
                out.append(Seg(text: String(boldPart), bold: true))
                remaining = afterOpen[close.upperBound...]
            } else {
                out.append(Seg(text: String(afterOpen), bold: false))
                return out
            }
        }
        if !remaining.isEmpty { out.append(Seg(text: String(remaining), bold: false)) }
        return out
    }

    private func roman(_ n: Int) -> String {
        // Small-int roman numerals keep the ledger feeling ledger-y. Caps at
        // 12 for safety — we never expect more findings than that.
        let table = ["", "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x", "xi", "xii"]
        if n >= 0 && n < table.count { return table[n] }
        return String(n)
    }
}

// MARK: - SwipeableLedgerRow
//
// Wraps BPLedgerRow with the previous view's swipe-to-dismiss gesture so the
// "swipe left on a card to dismiss" hint in the section sub-title is honored.

private struct SwipeableLedgerRow: View {
    let suggestion: AnalyticsSuggestion
    let index: Int
    let onTapped: () -> Void
    let onDismiss: () -> Void

    @State private var offset: CGFloat = 0
    @State private var restingOffset: CGFloat = 0

    private let actionWidth: CGFloat = 80
    private let fullSwipeThreshold: CGFloat = 140

    var body: some View {
        ZStack(alignment: .trailing) {
            if offset < -1 {
                trashAction
            }
            rowContent
                .offset(x: offset)
                .gesture(swipeGesture)
        }
        .onAppear { onTapped() }
    }

    private var rowContent: some View {
        let confPct = Int((suggestion.confidence * 100).rounded())
        let relative = bpRelativeFormatter.localizedString(for: suggestion.createdAt, relativeTo: .now)
        return BPLedgerRow(
            index: index,
            title: suggestion.parameter.bowParameterDisplayName,
            detail: suggestion.resolvedInlineSummary,
            monoLine: "\(confPct)% confidence · \(relative)",
            stamp: suggestion.resolvedStatusStamp,
            stampTone: suggestion.resolvedStampTone,
            accessory: AnyView(confidenceBar(width: 40, pct: suggestion.confidence))
        )
        .contentShape(Rectangle())
        .background(Color.appPaper)
    }

    private func confidenceBar(width: CGFloat, pct: Double) -> some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Color.appLine).frame(width: width, height: 2)
            Rectangle().fill(Color.appPond).frame(width: width * CGFloat(max(0, min(1, pct))), height: 2)
        }
    }

    private var trashAction: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                offset = 0
                restingOffset = 0
            }
            onDismiss()
        } label: {
            ZStack {
                Rectangle().fill(Color.appMaple)
                Text("Dismiss")
                    .font(.bpUI(9, weight: .semibold))
                    .tracking(9 * 0.22)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.appPaper)
            }
            .frame(width: actionWidth)
        }
        .buttonStyle(.plain)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let proposed = restingOffset + value.translation.width
                offset = proposed < 0 ? proposed : proposed / 5
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.width - value.translation.width
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    if offset < -fullSwipeThreshold || (velocity < -300 && offset < -actionWidth / 2) {
                        offset = 0
                        restingOffset = 0
                        onDismiss()
                    } else if offset < -actionWidth / 2 {
                        offset = -actionWidth
                        restingOffset = -actionWidth
                    } else {
                        offset = 0
                        restingOffset = 0
                    }
                }
            }
    }
}

// MARK: - FiltersSheet
//
// The existing bottom sheet — visual chrome touched-up to match the Wave 1
// token palette (flat rectangles, Kenrokuen colors, BP typography) while
// keeping the behavior and state intact.

private struct FiltersSheet: View {
    @Bindable var viewModel: AnalyticsViewModel
    let store: LocalStore
    let appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if stylesOwned.count >= 2 {
                        section(title: "Bow type") {
                            pillRow {
                                pill(label: "All", isSelected: viewModel.selectedBowType == nil) {
                                    await viewModel.selectBowType(nil)
                                }
                                ForEach(BowType.allCases, id: \.self) { type in
                                    if stylesOwned.contains(type) {
                                        pill(label: type.label, isSelected: viewModel.selectedBowType == type) {
                                            await viewModel.selectBowType(type)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if distancesUsed.count >= 2 {
                        section(title: "Distance") {
                            pillRow {
                                pill(label: "All", isSelected: viewModel.selectedDistance == nil) {
                                    await viewModel.selectDistance(nil)
                                }
                                ForEach(ShootingDistance.allCases, id: \.self) { distance in
                                    if distancesUsed.contains(distance) {
                                        pill(label: distance.label, isSelected: viewModel.selectedDistance == distance) {
                                            await viewModel.selectDistance(distance)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    section(title: "Time range") {
                        pillRow {
                            ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                                pill(label: period.label, isSelected: viewModel.selectedPeriod == period) {
                                    await viewModel.selectPeriod(period)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.appPaper)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.bpUI(13, weight: .semibold))
                        .foregroundStyle(Color.appPondDk)
                }
            }
        }
    }

    private var stylesOwned: Set<BowType> { Set(appState.bows.map(\.bowType)) }
    private var distancesUsed: Set<ShootingDistance> {
        (try? store.fetchSessions()).map { Set($0.compactMap(\.distance)) } ?? []
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            BPEyebrow(title.uppercased())
            content()
        }
    }

    @ViewBuilder
    private func pillRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) { content() }
        }
    }

    private func pill(label: String, isSelected: Bool, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(label)
                .font(.bpUI(11.5, weight: .semibold))
                .foregroundStyle(isSelected ? Color.appPaper : Color.appPondDk)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.appPondDk : Color.appPaper2)
                .overlay(Rectangle().strokeBorder(Color.appLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Previews

#Preview("Loaded – Kenrokuen") {
    let appState = AppState()
    appState.bows = [
        Bow(id: "b1", userId: "u1", name: "Hoyt RX7", bowType: .compound, brand: "Hoyt", model: "RX7", createdAt: .now),
    ]
    return NavigationStack {
        AnalyticsView()
    }
    .environment(appState)
}
