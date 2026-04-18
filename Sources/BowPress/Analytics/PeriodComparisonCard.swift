import SwiftUI

// MARK: - ComparisonHeatMapView

struct ComparisonHeatMapView: View {
    let currentPlots: [ArrowPlot]
    let previousPlots: [ArrowPlot]

    private let previousColor = Color(red: 0.55, green: 0.10, blue: 0.90)
    private let currentColor  = Color(red: 0.95, green: 0.10, blue: 0.15)

    var body: some View {
        Image("target_face")
            .resizable()
            .scaledToFit()
            // Previous period blobs
            .overlay {
                Canvas { context, size in
                    for (i, plot) in previousPlots.enumerated() {
                        let pt = position(for: plot, jitterIndex: i, in: size)
                        let rect = CGRect(x: pt.x - 22, y: pt.y - 22, width: 44, height: 44)
                        context.fill(Path(ellipseIn: rect), with: .color(previousColor.opacity(0.65)))
                    }
                }
                .drawingGroup()
                .blur(radius: 10)
            }
            // Current period blobs
            .overlay {
                Canvas { context, size in
                    for (i, plot) in currentPlots.enumerated() {
                        let pt = position(for: plot, jitterIndex: i, in: size)
                        let rect = CGRect(x: pt.x - 22, y: pt.y - 22, width: 44, height: 44)
                        context.fill(Path(ellipseIn: rect), with: .color(currentColor.opacity(0.65)))
                    }
                }
                .drawingGroup()
                .blur(radius: 10)
            }
            // Centroid markers — solid dot with black ring showing average impact point
            .overlay {
                Canvas { context, size in
                    let r: CGFloat = 14
                    let borderW: CGFloat = 2.5
                    if let pc = centroid(for: previousPlots, in: size) {
                        let fill = CGRect(x: pc.x - r, y: pc.y - r, width: r * 2, height: r * 2)
                        let ring = CGRect(x: pc.x - r - borderW, y: pc.y - r - borderW,
                                          width: (r + borderW) * 2, height: (r + borderW) * 2)
                        context.fill(Path(ellipseIn: fill), with: .color(previousColor))
                        context.stroke(Path(ellipseIn: ring), with: .color(.black.opacity(0.85)), lineWidth: borderW)
                    }
                    if let cc = centroid(for: currentPlots, in: size) {
                        let fill = CGRect(x: cc.x - r, y: cc.y - r, width: r * 2, height: r * 2)
                        let ring = CGRect(x: cc.x - r - borderW, y: cc.y - r - borderW,
                                          width: (r + borderW) * 2, height: (r + borderW) * 2)
                        context.fill(Path(ellipseIn: fill), with: .color(currentColor))
                        context.stroke(Path(ellipseIn: ring), with: .color(.black.opacity(0.85)), lineWidth: borderW)
                    }
                }
            }
            .clipShape(Circle())
    }

    // MARK: - Position helpers

    private func position(for plot: ArrowPlot, jitterIndex: Int, in size: CGSize) -> CGPoint {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let halfW  = size.width / 2

        let normalizedRadius: Double
        switch plot.ring {
        case 11: normalizedRadius = 0.08
        case 10: normalizedRadius = 0.245
        case 9:  normalizedRadius = 0.494
        default: normalizedRadius = 0.83
        }

        let baseAngle: Double
        switch plot.zone {
        case .center: baseAngle = Double(jitterIndex % 6) * .pi / 3
        case .n:      baseAngle =  .pi / 2
        case .ne:     baseAngle =  .pi / 4
        case .e:      baseAngle =  0
        case .se:     baseAngle = -.pi / 4
        case .s:      baseAngle = -.pi / 2
        case .sw:     baseAngle = -.pi * 3 / 4
        case .w:      baseAngle =  .pi
        case .nw:     baseAngle =  .pi * 3 / 4
        }

        let jitter = Double(jitterIndex % 5) * 0.12 - 0.24
        let angle  = baseAngle + jitter
        let r      = normalizedRadius * halfW * 0.92

        return CGPoint(x: center.x + r * cos(angle), y: center.y - r * sin(angle))
    }

    private func centroid(for plots: [ArrowPlot], in size: CGSize) -> CGPoint? {
        guard !plots.isEmpty else { return nil }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let halfW  = size.width / 2
        var sumX: Double = 0, sumY: Double = 0
        for plot in plots {
            let nr: Double
            switch plot.ring {
            case 11: nr = 0.0
            case 10: nr = 0.245
            case 9:  nr = 0.494
            default: nr = 0.83
            }
            let angle: Double
            switch plot.zone {
            case .center: angle = 0
            case .n:  angle =  .pi / 2
            case .ne: angle =  .pi / 4
            case .e:  angle =  0
            case .se: angle = -.pi / 4
            case .s:  angle = -.pi / 2
            case .sw: angle = -.pi * 3 / 4
            case .w:  angle =  .pi
            case .nw: angle =  .pi * 3 / 4
            }
            let r = nr * halfW * 0.92
            sumX += center.x + r * cos(angle)
            sumY += center.y - r * sin(angle)
        }
        let n = Double(plots.count)
        return CGPoint(x: sumX / n, y: sumY / n)
    }
}

// MARK: - PeriodComparisonCard

struct PeriodComparisonCard: View {
    let comparison: PeriodComparison

    private let previousColor = Color(red: 0.55, green: 0.10, blue: 0.90)
    private let currentColor  = Color(red: 0.95, green: 0.10, blue: 0.15)

    private var insights: [Insight] { buildInsights() }

    var body: some View {
        VStack(spacing: 0) {

            // ── Target heat map ──
            ComparisonHeatMapView(
                currentPlots: comparison.current.plots,
                previousPlots: comparison.previous.plots
            )
            .padding(12)
            .frame(maxWidth: .infinity)

            // ── Stats & insights ──
            VStack(alignment: .leading, spacing: 14) {

                // Legend
                HStack(spacing: 20) {
                    Spacer()
                    legendDot(color: previousColor, label: comparison.previous.label)
                    legendDot(color: currentColor,  label: comparison.current.label)
                    Spacer()
                }

                Divider()

                // Score comparison
                HStack(spacing: 0) {
                    scoreColumn(comparison.previous, alignment: .leading)
                    Spacer()
                    deltaBadge
                    Spacer()
                    scoreColumn(comparison.current, alignment: .trailing)
                }

                // Insights
                if !insights.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Insights")
                            .font(.subheadline.weight(.semibold))
                        ForEach(insights) { insight in
                            InsightRow(insight: insight)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .fill(Color.appSurface)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .strokeBorder(Color.appBorder, lineWidth: 1)
        )
    }

    // MARK: - Legend dot

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Score column

    private func scoreColumn(_ slice: PeriodSlice, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(String(format: "%.1f", slice.avgArrowScore))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(slice.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(slice.sessionCount) session\(slice.sessionCount == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Delta badge

    private var deltaBadge: some View {
        let delta = comparison.current.avgArrowScore - comparison.previous.avgArrowScore
        let isPositive = delta >= 0
        let sign = isPositive ? "▲ +" : "▼ "
        let formatted = String(format: "%.1f pts", abs(delta))
        let badgeColor: Color = isPositive ? .appAccent : .orange

        return Text("\(sign)\(formatted)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(isPositive ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(badgeColor.opacity(isPositive ? 0.9 : 0.18)))
    }

    // MARK: - Insight model

    struct Insight: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
        let kind: Kind

        enum Kind { case positive, negative, neutral, config }
    }

    // MARK: - Insights builder

    private func buildInsights() -> [Insight] {
        var result: [Insight] = []
        let cur  = comparison.current
        let prev = comparison.previous
        guard prev.avgArrowScore > 0 else { return result }

        // 1. Centroid shift — where shots are landing
        let prevC = normalizedCentroid(prev.plots)
        let curC  = normalizedCentroid(cur.plots)
        let prevDist = hypot(prevC.x, prevC.y)
        let curDist  = hypot(curC.x, curC.y)

        if abs(prevDist - curDist) >= 0.08 {
            if curDist < prevDist {
                let pct = Int(((prevDist - curDist) / max(prevDist, 0.01)) * 100)
                result.append(Insight(
                    icon: "scope",
                    text: "Shots are landing closer to center this period — impact tightened ~\(pct)% toward X ring",
                    kind: .positive
                ))
            } else {
                result.append(Insight(
                    icon: "scope",
                    text: "Groups spread further from center compared to \(prev.label.lowercased())",
                    kind: .negative
                ))
            }
        }

        // 2. Directional shift
        let dx = curC.x - prevC.x
        let dy = curC.y - prevC.y
        let shiftMag = hypot(dx, dy)
        if shiftMag >= 0.12 {
            let dir = primaryDirection(dx: dx, dy: dy)
            result.append(Insight(
                icon: "arrow.up.left.and.arrow.down.right",
                text: "Impact point shifted \(dir) from \(prev.label.lowercased())",
                kind: .neutral
            ))
        }

        // 3. X-ring rate
        let curX  = xRingRate(cur.plots)
        let prevX = xRingRate(prev.plots)
        if abs(curX - prevX) >= 0.05 {
            let improved = curX > prevX
            result.append(Insight(
                icon: improved ? "star.fill" : "star",
                text: String(format: "X-ring rate: %.0f%% → %.0f%%", prevX * 100, curX * 100),
                kind: improved ? .positive : .negative
            ))
        }

        // 4. 10+ ring rate
        let cur10  = ringPlusRate(cur.plots,  minRing: 10)
        let prev10 = ringPlusRate(prev.plots, minRing: 10)
        if abs(cur10 - prev10) >= 0.08 {
            let improved = cur10 > prev10
            result.append(Insight(
                icon: improved ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                text: String(format: "10-ring+ rate: %.0f%% → %.0f%%", prev10 * 100, cur10 * 100),
                kind: improved ? .positive : .negative
            ))
        }

        // 5. Session count change
        if cur.sessionCount != prev.sessionCount {
            let more = cur.sessionCount > prev.sessionCount
            result.append(Insight(
                icon: "calendar",
                text: "Sessions logged: \(prev.sessionCount) → \(cur.sessionCount)\(more ? " — more range time this period" : "")",
                kind: .neutral
            ))
        }

        // 6. Bow configuration changes
        if let prevCfg = prev.config, let curCfg = cur.config, prevCfg.id != curCfg.id {
            result.append(contentsOf: configInsights(from: prevCfg, to: curCfg))
        }

        return Array(result.prefix(6))
    }

    // MARK: - Config diff insights

    private func configInsights(from prev: BowConfiguration, to cur: BowConfiguration) -> [Insight] {
        var items: [Insight] = []

        let sightDelta = cur.sightPosition - prev.sightPosition
        if sightDelta != 0 {
            let dir = sightDelta > 0 ? "back \(abs(sightDelta)) step\(abs(sightDelta)==1 ? "" : "s")"
                                     : "forward \(abs(sightDelta)) step\(abs(sightDelta)==1 ? "" : "s")"
            items.append(Insight(
                icon: "tuningfork",
                text: "Sight rod moved \(dir) — likely corrected \(sightDelta > 0 ? "high" : "low") impact pattern",
                kind: .config
            ))
        }

        let nockDelta = cur.nockingHeight - prev.nockingHeight
        if nockDelta != 0 {
            items.append(Insight(
                icon: "tuningfork",
                text: "Nocking point \(nockDelta > 0 ? "raised" : "lowered") \(abs(nockDelta))/16\" — shifts vertical impact",
                kind: .config
            ))
        }

        let restVDelta = cur.restVertical - prev.restVertical
        if restVDelta != 0 {
            items.append(Insight(
                icon: "tuningfork",
                text: "Rest \(restVDelta > 0 ? "raised" : "lowered") — adjusts vertical clearance and arrow travel",
                kind: .config
            ))
        }

        let cableDelta = (cur.topCableTwists + cur.bottomCableTwists)
                       - (prev.topCableTwists + prev.bottomCableTwists)
        if cableDelta != 0 {
            items.append(Insight(
                icon: "tuningfork",
                text: "Cable twists \(cableDelta > 0 ? "added" : "removed") — adjusts cam timing and draw length",
                kind: .config
            ))
        }

        let limbDelta = (cur.topLimbTurns + cur.bottomLimbTurns)
                      - (prev.topLimbTurns + prev.bottomLimbTurns)
        if limbDelta != 0 {
            items.append(Insight(
                icon: "tuningfork",
                text: "Limb bolts \(limbDelta > 0 ? "tightened" : "backed out") — changed draw weight and timing",
                kind: .config
            ))
        }

        return Array(items.prefix(2))
    }

    // MARK: - Centroid helpers

    private func normalizedCentroid(_ plots: [ArrowPlot]) -> (x: Double, y: Double) {
        guard !plots.isEmpty else { return (0, 0) }
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
            case .n:  angle =  .pi / 2
            case .ne: angle =  .pi / 4
            case .e:  angle =  0
            case .se: angle = -.pi / 4
            case .s:  angle = -.pi / 2
            case .sw: angle = -.pi * 3 / 4
            case .w:  angle =  .pi
            case .nw: angle =  .pi * 3 / 4
            }
            sumX += r * cos(angle)
            sumY += r * sin(angle) // positive y = north/up on target
        }
        let n = Double(plots.count)
        return (x: sumX / n, y: sumY / n)
    }

    private func primaryDirection(dx: Double, dy: Double) -> String {
        let adx = abs(dx), ady = abs(dy)
        if ady > adx * 1.7 {
            return dy > 0 ? "higher (north)" : "lower (south)"
        } else if adx > ady * 1.7 {
            return dx > 0 ? "right" : "left"
        } else {
            return "\(dy > 0 ? "high" : "low")-\(dx > 0 ? "right" : "left")"
        }
    }

    // MARK: - Rate helpers

    private func xRingRate(_ plots: [ArrowPlot]) -> Double {
        guard !plots.isEmpty else { return 0 }
        return Double(plots.filter { $0.ring == 11 }.count) / Double(plots.count)
    }

    private func ringPlusRate(_ plots: [ArrowPlot], minRing: Int) -> Double {
        guard !plots.isEmpty else { return 0 }
        return Double(plots.filter { $0.ring >= minRing }.count) / Double(plots.count)
    }
}

// MARK: - InsightRow

private struct InsightRow: View {
    let insight: PeriodComparisonCard.Insight

    private var accentColor: Color {
        switch insight.kind {
        case .positive: return .appAccent
        case .negative: return .orange
        case .neutral:  return .secondary
        case .config:   return Color(red: 0.55, green: 0.10, blue: 0.90)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: insight.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentColor)
                .frame(width: 16)
            Text(insight.text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#Preview("Period Comparison") {
    ScrollView {
        #if DEBUG
        PeriodComparisonCard(
            comparison: DevMockData.comparison(period: .week)
        )
        .padding(16)
        .background(Color.appBackground)
        #endif
    }
}
