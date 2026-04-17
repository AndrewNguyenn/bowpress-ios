import SwiftUI

// MARK: - OverviewCard

struct OverviewCard: View {
    let overview: AnalyticsOverview

    private var scoreColor: Color {
        switch overview.avgScore {
        case 75...:   return Color.appAccent
        case 50..<75: return .orange
        default:      return .red
        }
    }

    private var topConfigLabel: String {
        guard let config = overview.topConfig else { return "—" }
        if let label = config.label, !label.isEmpty { return label }
        return config.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Period header
            Text("Last \(overview.period.label)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appText)
                .textCase(.uppercase)
                .kerning(0.5)

            HStack(alignment: .center, spacing: 24) {

                // Circular score gauge
                Gauge(value: overview.avgScore, in: 0...100) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(Int(overview.avgScore.rounded()))")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(scoreColor)
                } minimumValueLabel: {
                    Text("0").font(.caption2).foregroundStyle(.tertiary)
                } maximumValueLabel: {
                    Text("100").font(.caption2).foregroundStyle(.tertiary)
                }
                .gaugeStyle(.accessoryCircular)
                .tint(scoreColor)
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(overview.avgScore.rounded()))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                        .contentTransition(.numericText())
                }

                Spacer()

                // Session count
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(overview.sessionCount)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text("sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Top config row
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.subheadline)
                    .foregroundStyle(.yellow)
                Text("Best config:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(topConfigLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appSurface)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    overview.avgScore >= 75 ? Color.appAccent.opacity(0.4) : Color.appBorder,
                    lineWidth: 1.5
                )
        )
        .animation(.easeInOut(duration: 0.3), value: overview.avgScore)
    }
}

// MARK: - Preview

#Preview("High score (≥75)") {
    OverviewCard(overview: .mockHighScore)
        .padding()
        .background(Color.appBackground)
}

#Preview("Mid score (50–74)") {
    OverviewCard(overview: .mockMidScore)
        .padding()
        .background(Color.appBackground)
}

#Preview("Low score (<50)") {
    OverviewCard(overview: .mockLowScore)
        .padding()
        .background(Color.appBackground)
}

// MARK: - Mock data

extension AnalyticsOverview {
    static let mockHighScore = AnalyticsOverview(
        bowId: "b1",
        period: .week,
        sessionCount: 5,
        avgScore: 85,
        topConfig: BowConfiguration.mockConfigs[4],
        suggestions: AnalyticsSuggestion.mockAllSuggestions
    )

    static let mockMidScore = AnalyticsOverview(
        bowId: "b1",
        period: .twoWeeks,
        sessionCount: 3,
        avgScore: 62,
        topConfig: BowConfiguration.mockConfigs[2],
        suggestions: []
    )

    static let mockLowScore = AnalyticsOverview(
        bowId: "b1",
        period: .month,
        sessionCount: 1,
        avgScore: 45,
        topConfig: nil,
        suggestions: []
    )
}

extension BowConfiguration {
    /// Five mock configs with progressively improving scores (45, 62, 78, 71, 85).
    static let mockConfigs: [BowConfiguration] = [
        BowConfiguration(
            id: "c1", bowId: "b1",
            createdAt: Date().addingTimeInterval(-86_400 * 28),
            label: "Initial Setup",
            drawLength: 28.0, letOffPct: 80,
            peepHeight: 9.0, dLoopLength: 2.0,
            topCableTwists: 0, bottomCableTwists: 0,
            mainStringTopTwists: 0, mainStringBottomTwists: 0,
            topLimbTurns: 0, bottomLimbTurns: 0,
            restVertical: 0, restHorizontal: 0, restDepth: 0,
            sightPosition: 0, gripAngle: 0, nockingHeight: 0,
            frontStabWeight: 12, frontStabAngle: 0,
            rearStabSide: .none, rearStabWeight: 0, rearStabVertAngle: 0, rearStabHorizAngle: 0
        ),
        BowConfiguration(
            id: "c2", bowId: "b1",
            createdAt: Date().addingTimeInterval(-86_400 * 21),
            label: "Rest Tune",
            drawLength: 28.0, letOffPct: 80,
            peepHeight: 9.0, dLoopLength: 2.0,
            topCableTwists: 2, bottomCableTwists: 2,
            mainStringTopTwists: 1, mainStringBottomTwists: 1,
            topLimbTurns: 0, bottomLimbTurns: 0,
            restVertical: 1, restHorizontal: 0, restDepth: 0,
            sightPosition: 0, gripAngle: 0, nockingHeight: 0,
            frontStabWeight: 12, frontStabAngle: 0,
            rearStabSide: .none, rearStabWeight: 0, rearStabVertAngle: 0, rearStabHorizAngle: 0
        ),
        BowConfiguration(
            id: "c3", bowId: "b1",
            createdAt: Date().addingTimeInterval(-86_400 * 14),
            label: "Paper Tune",
            drawLength: 28.5, letOffPct: 80,
            peepHeight: 9.0, dLoopLength: 2.0,
            topCableTwists: 2, bottomCableTwists: 2,
            mainStringTopTwists: 1, mainStringBottomTwists: 1,
            topLimbTurns: 0.5, bottomLimbTurns: 0.5,
            restVertical: 1, restHorizontal: 1, restDepth: 0.25,
            sightPosition: 1, gripAngle: 5.0, nockingHeight: 2,
            frontStabWeight: 12, frontStabAngle: 5,
            rearStabSide: .left, rearStabWeight: 8, rearStabVertAngle: -45, rearStabHorizAngle: 45
        ),
        BowConfiguration(
            id: "c4", bowId: "b1",
            createdAt: Date().addingTimeInterval(-86_400 * 7),
            label: "Nocking Adjust",
            drawLength: 28.5, letOffPct: 80,
            peepHeight: 9.25, dLoopLength: 2.0,
            topCableTwists: 2, bottomCableTwists: 2,
            mainStringTopTwists: 1, mainStringBottomTwists: 1,
            topLimbTurns: 0.5, bottomLimbTurns: 0.5,
            restVertical: 1, restHorizontal: 1, restDepth: 0.25,
            sightPosition: 1, gripAngle: 5.0, nockingHeight: 3,
            frontStabWeight: 12, frontStabAngle: 5,
            rearStabSide: .left, rearStabWeight: 8, rearStabVertAngle: -45, rearStabHorizAngle: 45
        ),
        BowConfiguration(
            id: "c5", bowId: "b1",
            createdAt: Date().addingTimeInterval(-86_400 * 2),
            label: "Competition Ready",
            drawLength: 28.5, letOffPct: 80,
            peepHeight: 9.25, dLoopLength: 2.125,
            topCableTwists: 3, bottomCableTwists: 3,
            mainStringTopTwists: 2, mainStringBottomTwists: 2,
            topLimbTurns: 0.5, bottomLimbTurns: 0.5,
            restVertical: 2, restHorizontal: 1, restDepth: 0.25,
            sightPosition: 1, gripAngle: 5.0, nockingHeight: 3,
            frontStabWeight: 14, frontStabAngle: 5,
            rearStabSide: .left, rearStabWeight: 10, rearStabVertAngle: -45, rearStabHorizAngle: 45
        ),
    ]

    /// Parallel scores for the five mock configs.
    static let mockScores: [Double] = [45, 62, 78, 71, 85]
}
