import SwiftUI

// MARK: - TrendInsight

struct TrendInsight: Identifiable {
    let id: String
    let icon: String
    let headline: String
    let detail: String
    let kind: Kind

    enum Kind { case positive, negative, neutral, info }
}

// MARK: - AnalyticsTrendInsightsSection

struct AnalyticsTrendInsightsSection: View {
    let comparison: PeriodComparison
    let overview: AnalyticsOverview
    var extraInsights: [TrendInsight] = []

    private let limit = 8
    @State private var showAll = false

    private var insights: [TrendInsight] { buildInsights() + extraInsights }

    private var visibleInsights: [TrendInsight] {
        showAll ? insights : Array(insights.prefix(limit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Text("Trend Analysis")
                    .font(.headline)
                if !insights.isEmpty {
                    Text("\(insights.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.appAccent, in: Capsule())
                }
                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(visibleInsights) { insight in
                    TrendInsightRow(insight: insight)
                }
            }

            if insights.count > limit {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { showAll.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(showAll ? "Show less" : "Show more trends")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: showAll ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.appAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.appAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Insight builder

    private func buildInsights() -> [TrendInsight] {
        var result: [TrendInsight] = []
        let cur  = comparison.current
        let prev = comparison.previous
        guard prev.avgArrowScore > 0 else { return result }

        let scoreDelta  = cur.avgArrowScore - prev.avgArrowScore
        let scorePct    = Int(abs(scoreDelta) / max(prev.avgArrowScore, 1) * 100)
        let cur10       = ringPlusRate(cur.plots,  minRing: 10)
        let prev10      = ringPlusRate(prev.plots, minRing: 10)
        let curX        = xRingRate(cur.plots)
        let prevX       = xRingRate(prev.plots)
        let centroid    = normalizedCentroid(cur.plots)
        let centroidDist = hypot(centroid.x, centroid.y)
        let sessionDelta = cur.sessionCount - prev.sessionCount

        // 1. Score momentum
        if abs(scoreDelta) >= 0.3 {
            let up = scoreDelta > 0
            result.append(TrendInsight(
                id: "score_momentum",
                icon: up ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                headline: up
                    ? "Scores up \(String(format: "%.1f", scoreDelta)) pts from \(prev.label.lowercased())"
                    : "Scores down \(String(format: "%.1f", abs(scoreDelta))) pts from \(prev.label.lowercased())",
                detail: up
                    ? "Average arrow score rose from \(String(format: "%.1f", prev.avgArrowScore)) to \(String(format: "%.1f", cur.avgArrowScore)) — a \(scorePct)% gain across \(cur.sessionCount) sessions. The upward trend suggests your form and tuning adjustments are taking hold."
                    : "Average score dropped from \(String(format: "%.1f", prev.avgArrowScore)) to \(String(format: "%.1f", cur.avgArrowScore)). Review your session feel-tags to identify whether fatigue, form drift, or conditions are the primary driver.",
                kind: up ? .positive : .negative
            ))
        }

        // 2. Grouping consistency — 10+ ring rate
        if cur10 > 0 || prev10 > 0 {
            let up = cur10 >= prev10
            result.append(TrendInsight(
                id: "consistency",
                icon: "scope",
                headline: String(format: "10-ring+ rate: %.0f%% → %.0f%%", prev10 * 100, cur10 * 100),
                detail: up
                    ? String(format: "%.0f%% of arrows landed in the 10-ring or better this period, up from %.0f%%. Tighter groupings at the top of the scoring zone indicate improving shot consistency and cleaner execution.", cur10 * 100, prev10 * 100)
                    : String(format: "10-ring+ rate dropped from %.0f%% to %.0f%%. Target panic, fatigue, or form drift are the most common causes — track feel tags in your next session to narrow it down.", prev10 * 100, cur10 * 100),
                kind: up ? .positive : .negative
            ))
        }

        // 3. Directional bias in current period
        // Elite archers need a much tighter threshold — sub-ring-level drift matters
        let isPrecision = overview.avgArrowScore >= 9.5
        let biasThreshold = isPrecision ? 0.04 : 0.12
        if centroidDist > biasThreshold {
            let dir = verboseDirection(centroid.x, centroid.y)
            if isPrecision {
                let distMM = String(format: "%.1f", centroidDist * mmPerNorm)
                result.append(TrendInsight(
                    id: "directional_bias",
                    icon: "location.circle",
                    headline: "Group center ~\(distMM)mm \(dir.short) of X",
                    detail: "\(dir.long) At this level a \(distMM)mm drift is meaningful — cross-reference with your feel tags. Common causes: peep height, nocking point position, or subtle anchor point drift.",
                    kind: .neutral
                ))
            } else {
                result.append(TrendInsight(
                    id: "directional_bias",
                    icon: "location.circle",
                    headline: "Groups trending \(dir.short) this period",
                    detail: "\(dir.long) Across \(cur.plots.count) shots this period, a consistent directional bias usually points to a repeatable form issue or sight misalignment — both are correctable once identified.",
                    kind: .neutral
                ))
            }
        }

        // 4. X-ring rate
        if curX >= 0.10 || prevX >= 0.10 {
            let up = curX >= prevX
            let commentary: String
            if curX >= 0.50 {
                commentary = "At 50%+ X-ring rate, you're shooting at a competitive indoor standard."
            } else if curX >= 0.25 {
                commentary = "Keep focusing on back tension and a clean release — X-ring consistency follows."
            } else {
                commentary = "X-ring rate below 25% typically means groups are centered but not tight enough. Try aiming at a smaller reference point."
            }
            result.append(TrendInsight(
                id: "x_ring",
                icon: up ? "star.fill" : "star",
                headline: String(format: "X-ring rate %@ to %.0f%%", up ? "up" : "down", curX * 100),
                detail: String(format: "X-ring (ring 11) hits: %.0f%% this period vs %.0f%% last. %@", curX * 100, prevX * 100, commentary),
                kind: up ? .positive : .neutral
            ))
        }

        // 5. Session volume
        if cur.sessionCount > 0 {
            let detail: String
            if sessionDelta > 0 {
                detail = "You put in more range time this period (\(cur.sessionCount) vs \(prev.sessionCount) sessions). Consistent volume is one of the strongest predictors of score improvement — keep the frequency up."
            } else if sessionDelta < 0 {
                detail = "Fewer sessions this period (\(cur.sessionCount) vs \(prev.sessionCount)). If scores dipped alongside volume, that's a clear signal that range frequency matters for your consistency."
            } else {
                detail = "Consistent session count (\(cur.sessionCount)) period over period. Stable volume helps isolate whether score changes are form- or tuning-related."
            }
            result.append(TrendInsight(
                id: "volume",
                icon: "calendar",
                headline: "\(cur.sessionCount) session\(cur.sessionCount == 1 ? "" : "s") this period\(sessionDelta != 0 ? " (\(sessionDelta > 0 ? "+" : "")\(sessionDelta) vs last)" : "")",
                detail: detail,
                kind: sessionDelta > 0 ? .positive : (sessionDelta < 0 ? .neutral : .info)
            ))
        }

        // 6. Tuning effect — config changed between periods
        if let prevCfg = prev.config, let curCfg = cur.config, prevCfg.id != curCfg.id {
            let positive = scoreDelta > 0 && (cur10 - prev10) > 0
            result.append(TrendInsight(
                id: "tuning_effect",
                icon: "wrench.and.screwdriver",
                headline: positive ? "Tuning change correlates with score gain" : "Tuning change — effect still developing",
                detail: positive
                    ? String(format: "A bow configuration change occurred between periods. Scores improved %.1f pts and 10-ring rate moved %.0f%% → %.0f%%. These gains align with the tuning adjustment.", scoreDelta, prev10 * 100, cur10 * 100)
                    : String(format: "A bow configuration change was made between periods. Scores shifted %.1f pts. Give it a few more sessions before drawing conclusions — new setups often need time to fully dial in.", scoreDelta),
                kind: positive ? .positive : .neutral
            ))
        }

        return Array(result.prefix(6))
    }

    // MARK: - Helpers

    private let mmPerNorm: Double = 20.0 / (119.0 / 735.0)  // ≈ 123.5mm (WA 40cm indoor target)

    private func normalizedCentroid(_ plots: [ArrowPlot]) -> (x: Double, y: Double) {
        guard !plots.isEmpty else { return (0, 0) }
        // Use actual plotX/plotY when available — far more precise than ring/zone reconstruction
        let realPts = plots.compactMap { p -> (Double, Double)? in
            guard let x = p.plotX, let y = p.plotY else { return nil }
            return (x, y)
        }
        if !realPts.isEmpty {
            return (x: realPts.map(\.0).reduce(0, +) / Double(realPts.count),
                    y: realPts.map(\.1).reduce(0, +) / Double(realPts.count))
        }
        // Fallback: ring/zone reconstruction (legacy data without stored coordinates)
        var sumX = 0.0, sumY = 0.0
        for plot in plots {
            let r: Double
            switch plot.ring {
            case 11: r = 0.0
            case 10: r = 0.245
            case 9:  r = 0.494
            default: r = 0.83
            }
            let angle: Double
            switch plot.zone {
            case .center: angle = 0
            case .n:      angle =  .pi / 2
            case .ne:     angle =  .pi / 4
            case .e:      angle =  0
            case .se:     angle = -.pi / 4
            case .s:      angle = -.pi / 2
            case .sw:     angle = -.pi * 3 / 4
            case .w:      angle =  .pi
            case .nw:     angle =  .pi * 3 / 4
            }
            sumX += r * cos(angle)
            sumY += r * sin(angle)
        }
        let n = Double(plots.count)
        return (x: sumX / n, y: sumY / n)
    }

    private func verboseDirection(_ x: Double, _ y: Double) -> (short: String, long: String) {
        let adx = abs(x), ady = abs(y)
        if ady > adx * 1.7 {
            return y > 0
                ? ("north", "Shots are consistently landing high (north of center).")
                : ("south", "Shots are consistently landing low (south of center).")
        } else if adx > ady * 1.7 {
            return x > 0
                ? ("right", "Shots are consistently landing right of center.")
                : ("left",  "Shots are consistently landing left of center.")
        } else {
            let v = y > 0 ? "high" : "low"
            let h = x > 0 ? "right" : "left"
            return ("\(v)-\(h)", "Shots are consistently landing \(v) and \(h) of center.")
        }
    }

    private func xRingRate(_ plots: [ArrowPlot]) -> Double {
        guard !plots.isEmpty else { return 0 }
        return Double(plots.filter { $0.ring == 11 }.count) / Double(plots.count)
    }

    private func ringPlusRate(_ plots: [ArrowPlot], minRing: Int) -> Double {
        guard !plots.isEmpty else { return 0 }
        return Double(plots.filter { $0.ring >= minRing }.count) / Double(plots.count)
    }
}

// MARK: - TrendInsightRow

private struct TrendInsightRow: View {
    let insight: TrendInsight

    private var accentColor: Color {
        switch insight.kind {
        case .positive: return .appAccent
        case .negative: return .orange
        case .neutral:  return Color(red: 0.55, green: 0.10, blue: 0.90)
        case .info:     return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: insight.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 20, height: 20)
                    .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(.top, 1)

                Text(insight.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(insight.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appSurface)
                .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accentColor.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Trend Insights") {
    ScrollView {
        #if DEBUG
        AnalyticsTrendInsightsSection(
            comparison: DevMockData.comparison(period: .week),
            overview: DevMockData.overview(period: .week)
        )
        .padding()
        #endif
    }
    .background(Color.appBackground)
}
