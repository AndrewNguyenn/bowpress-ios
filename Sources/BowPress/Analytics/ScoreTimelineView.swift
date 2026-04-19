import SwiftUI
import Charts

// MARK: - ScoreTimelineView

struct ScoreTimelineView: View {
    var overview: AnalyticsOverview
    var allConfigs: [BowConfiguration]  // chronological order

    // Associates each config with its score (derived from mock data in previews;
    // in production the overview would carry per-config scores).
    private var dataPoints: [(config: BowConfiguration, score: Double)] {
        // In a real implementation the API would return per-config scores.
        // We derive scores from overview mock data by spreading avgScore with
        // a simple sinusoidal variation so the chart is always meaningful.
        let configs = allConfigs.sorted { $0.createdAt < $1.createdAt }
        guard !configs.isEmpty else { return [] }
        return configs.enumerated().map { idx, config in
            let score: Double
            if idx < BowConfiguration.mockScores.count {
                score = BowConfiguration.mockScores[idx]
            } else {
                let variation = (Double(idx % 3) - 1.0) * 0.4
                score = max(6, min(11, overview.avgArrowScore + variation))
            }
            return (config: config, score: score)
        }
    }

    private var bestScore: Double {
        dataPoints.map(\.score).max() ?? overview.avgArrowScore
    }

    private var bestConfig: BowConfiguration? {
        dataPoints.max(by: { $0.score < $1.score })?.config
    }

    @State private var selectedConfig: BowConfiguration?
    @State private var committedZoom: CGFloat = 1.0
    @State private var liveZoom: CGFloat = 1.0

    private var fullDateRange: ClosedRange<Date>? {
        let dates = dataPoints.map(\.config.createdAt)
        guard let earliest = dates.min(), let latest = dates.max() else { return nil }
        if earliest == latest {
            return earliest.addingTimeInterval(-86_400)...earliest.addingTimeInterval(86_400)
        }
        return earliest...latest
    }

    // Fraction of the full span that should be visible. Pinch out → scale > 1 → smaller fraction → magnified.
    private var currentZoom: CGFloat {
        min(max(committedZoom / liveZoom, 0.2), 1.0)
    }

    private var visibleDateRange: ClosedRange<Date>? {
        guard let full = fullDateRange else { return nil }
        let totalSpan = full.upperBound.timeIntervalSince(full.lowerBound)
        let visibleSpan = totalSpan * Double(currentZoom)
        let center = full.lowerBound.addingTimeInterval(totalSpan / 2)
        return center.addingTimeInterval(-visibleSpan / 2)...center.addingTimeInterval(visibleSpan / 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section title
            Label("Score Timeline", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
                .foregroundStyle(.primary)

            if dataPoints.isEmpty {
                emptyTimelineView
            } else {
                chartView
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appSurface)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }

    // MARK: - Chart

    private var chartView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                // Best-score reference rule
                RuleMark(y: .value("Best", bestScore))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(Color.appAccent.opacity(0.6))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Best")
                            .font(.caption2)
                            .foregroundStyle(Color.appAccent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.appAccent.opacity(0.1), in: Capsule())
                    }

                // Line connecting config scores
                ForEach(dataPoints, id: \.config.id) { point in
                    LineMark(
                        x: .value("Date", point.config.createdAt),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(Color.appAccent.opacity(0.85))
                    .interpolationMethod(.catmullRom)
                }

                // Point marks
                ForEach(dataPoints, id: \.config.id) { point in
                    PointMark(
                        x: .value("Date", point.config.createdAt),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(point.score >= bestScore * 0.9 ? Color.appAccent : Color.orange)
                    .symbolSize(point.config.id == selectedConfig?.id ? 140 : 80)
                    .annotation(position: .top) {
                        if point.config.id == selectedConfig?.id {
                            annotationView(for: point)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.appBorder.opacity(0.6))
                    AxisValueLabel(format: .dateTime.month().day())
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(values: .stride(by: 1)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.appBorder.opacity(0.6))
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .chartYScale(domain: 6...11)
            .chartXScale(domain: visibleDateRange ?? fullDateRange ?? (Date()...Date().addingTimeInterval(86_400)))
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            handleTap(at: location, proxy: proxy, geometry: geo)
                        }
                }
            }
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { scale in liveZoom = scale }
                    .onEnded { scale in
                        committedZoom = min(max(committedZoom / scale, 0.2), 1.0)
                        liveZoom = 1.0
                    }
            )
            .frame(height: 200)
            .animation(.easeInOut(duration: 0.2), value: selectedConfig?.id)

            // Legend
            HStack(spacing: 16) {
                legendDot(color: .appAccent, label: "Strong")
                legendDot(color: .orange, label: "Lower")
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.appAccent.opacity(0.5))
                        .frame(width: 14, height: 1.5)
                        .overlay(
                            HStack(spacing: 2) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Circle().frame(width: 2, height: 2).foregroundStyle(Color.appAccent.opacity(0.5))
                                }
                            }
                        )
                    Text("Best")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func annotationView(for point: (config: BowConfiguration, score: Double)) -> some View {
        VStack(spacing: 2) {
            Text(point.config.label ?? point.config.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            Text(String(format: "%.1f", point.score))
                .font(.caption.weight(.bold))
                .foregroundStyle(point.score >= bestScore * 0.95 ? Color.appAccent : Color.orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.appSurface)
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        )
    }

    private var emptyTimelineView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 36))
                    .foregroundStyle(.quaternary)
                Text("Not enough data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 32)
            Spacer()
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Tap handling

    private func handleTap(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let origin = geometry[proxy.plotFrame!].origin
        let plotLocation = CGPoint(
            x: location.x - origin.x,
            y: location.y - origin.y
        )
        guard let tappedDate: Date = proxy.value(atX: plotLocation.x) else { return }
        // Find the closest data point to the tapped X position.
        let closest = dataPoints.min(by: {
            abs($0.config.createdAt.timeIntervalSince(tappedDate)) <
            abs($1.config.createdAt.timeIntervalSince(tappedDate))
        })
        withAnimation {
            if selectedConfig?.id == closest?.config.id {
                selectedConfig = nil
            } else {
                selectedConfig = closest?.config
            }
        }
    }
}

// MARK: - Fallback bar list (used when Charts is unavailable / as an alternative)

struct ScoreFallbackBarList: View {
    let dataPoints: [(label: String, score: Double)]
    let bestScore: Double

    var body: some View {
        VStack(spacing: 8) {
            ForEach(dataPoints, id: \.label) { point in
                HStack(spacing: 10) {
                    Text(point.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.systemFill))
                                .frame(height: 10)
                            Capsule()
                                .fill(point.score >= bestScore * 0.95 ? Color.appAccent : Color.orange)
                                .frame(width: geo.size.width * ((point.score - 6) / 5), height: 10)
                        }
                    }
                    .frame(height: 10)
                    Text(String(format: "%.1f", point.score))
                        .font(.caption.weight(.semibold))
                        .frame(width: 32, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Score Timeline – full data") {
    ScrollView {
        ScoreTimelineView(
            overview: .mockHighScore,
            allConfigs: BowConfiguration.mockConfigs
        )
        .padding()
    }
    .background(Color.appBackground)
}

#Preview("Score Timeline – empty") {
    ScrollView {
        ScoreTimelineView(
            overview: .mockHighScore,
            allConfigs: []
        )
        .padding()
    }
    .background(Color.appBackground)
}
