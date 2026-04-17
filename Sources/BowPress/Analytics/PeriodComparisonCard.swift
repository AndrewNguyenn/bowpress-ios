import SwiftUI

// MARK: - ComparisonHeatMapView

struct ComparisonHeatMapView: View {
    let currentPlots: [ArrowPlot]
    let previousPlots: [ArrowPlot]

    private let previousColor = Color.orange.opacity(0.70)
    private let currentColor  = Color.appAccent.opacity(0.80)

    var body: some View {
        Image("target_face")
            .resizable()
            .scaledToFit()
            // Previous period blobs — canvas is sized to match the rendered image
            .overlay {
                Canvas { context, size in
                    for (i, plot) in previousPlots.enumerated() {
                        let pt = position(for: plot, jitterIndex: i, in: size)
                        let rect = CGRect(x: pt.x - 20, y: pt.y - 20, width: 40, height: 40)
                        context.fill(Path(ellipseIn: rect), with: .color(previousColor))
                    }
                }
                .drawingGroup()
                .blur(radius: 9)
            }
            // Current period blobs
            .overlay {
                Canvas { context, size in
                    for (i, plot) in currentPlots.enumerated() {
                        let pt = position(for: plot, jitterIndex: i, in: size)
                        let rect = CGRect(x: pt.x - 20, y: pt.y - 20, width: 40, height: 40)
                        context.fill(Path(ellipseIn: rect), with: .color(currentColor))
                    }
                }
                .drawingGroup()
                .blur(radius: 9)
            }
            // Circular clip removes white margin, barcode, and any printed logos
            .clipShape(Circle())
    }

    // MARK: - Position Calculation

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

        let jitter = Double(jitterIndex % 5) * 0.12 - 0.24   // ±0.24 rad spread
        let angle  = baseAngle + jitter
        let r      = normalizedRadius * halfW * 0.92          // 92% to stay inside edge

        return CGPoint(
            x: center.x + r * cos(angle),
            y: center.y - r * sin(angle)
        )
    }
}

// MARK: - PeriodComparisonCard

struct PeriodComparisonCard: View {
    let comparison: PeriodComparison

    private let previousColor = Color.orange
    private let currentColor  = Color.appAccent

    private var observations: [String] { buildObservations() }

    var body: some View {
        VStack(spacing: 0) {

            // ── Target heat map — full width, centered, no padding ──
            ComparisonHeatMapView(
                currentPlots: comparison.current.plots,
                previousPlots: comparison.previous.plots
            )
            .padding(12)           // breathing room before the circular clip edge
            .frame(maxWidth: .infinity)

            // ── Stats & observations ──
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

                // Observations
                if !observations.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What changed")
                            .font(.subheadline.weight(.semibold))
                        ForEach(observations, id: \.self) { obs in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•").foregroundStyle(.secondary)
                                Text(obs)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
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
            Text(String(format: "%.1f", slice.avgScore))
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
        let delta = comparison.current.avgScore - comparison.previous.avgScore
        let isPositive = delta >= 0
        let sign = isPositive ? "▲ +" : "▼ "
        let formatted = String(format: "%.1f pts", abs(delta))
        let badgeColor: Color = isPositive ? .appAccent : .orange

        return Text("\(sign)\(formatted)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(isPositive ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(badgeColor.opacity(isPositive ? 0.9 : 0.18))
            )
    }

    // MARK: - Observations builder

    private func buildObservations() -> [String] {
        var result: [String] = []
        let cur  = comparison.current
        let prev = comparison.previous

        guard prev.avgScore > 0 else { return result }

        // 1. Score delta
        let scoreDelta = cur.avgScore - prev.avgScore
        let scorePct   = (scoreDelta / prev.avgScore) * 100
        let direction  = scoreDelta >= 0 ? "improved" : "dropped"
        let sign       = scoreDelta >= 0 ? "+" : ""
        result.append(
            String(format: "Score %@ %@%.1f pts (%@%.0f%%) from %@",
                   direction, sign, scoreDelta, sign, scorePct, prev.label.lowercased())
        )

        // 2. X-ring (ring 11) rate
        let curXRate  = xRingRate(cur.plots)
        let prevXRate = xRingRate(prev.plots)
        if abs(curXRate - prevXRate) >= 0.05 {
            result.append(
                String(format: "X-ring rate: %.0f%% → %.0f%%",
                       prevXRate * 100, curXRate * 100)
            )
        }

        // 3. 10+ ring rate
        let cur10Rate  = ringPlusRate(cur.plots,  minRing: 10)
        let prev10Rate = ringPlusRate(prev.plots, minRing: 10)
        if abs(cur10Rate - prev10Rate) >= 0.08 {
            result.append(
                String(format: "10-ring+ rate: %.0f%% → %.0f%%",
                       prev10Rate * 100, cur10Rate * 100)
            )
        }

        // 4. Session count change
        if cur.sessionCount != prev.sessionCount {
            result.append(
                "Sessions: \(prev.sessionCount) → \(cur.sessionCount)"
            )
        }

        return Array(result.prefix(4))
    }

    // MARK: - Rate helpers

    private func xRingRate(_ plots: [ArrowPlot]) -> Double {
        guard !plots.isEmpty else { return 0 }
        let count = plots.filter { $0.ring == 11 }.count
        return Double(count) / Double(plots.count)
    }

    private func ringPlusRate(_ plots: [ArrowPlot], minRing: Int) -> Double {
        guard !plots.isEmpty else { return 0 }
        let count = plots.filter { $0.ring >= minRing }.count
        return Double(count) / Double(plots.count)
    }
}

// MARK: - Preview

#Preview("Period Comparison") {
    ScrollView {
        #if DEBUG
        PeriodComparisonCard(
            comparison: DevMockData.comparison(bowId: "dev_bow1", period: .week)
        )
        .padding(16)
        .background(Color.appBackground)
        #endif
    }
}
