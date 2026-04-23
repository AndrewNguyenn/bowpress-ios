import SwiftUI

// MARK: - OverviewCard

struct OverviewCard: View {
    let overview: AnalyticsOverview

    private var scoreColor: Color {
        switch overview.avgArrowScore {
        case 10...: return Color.appAccent
        case 9..<10: return .orange
        default:    return .red
        }
    }

    private var scoreString: String {
        overview.avgArrowScore >= 9.8
            ? String(format: "%.2f", overview.avgArrowScore)
            : String(format: "%.1f", overview.avgArrowScore)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            Text("Last \(overview.period.label)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.appText)
                .textCase(.uppercase)
                .kerning(0.5)

            HStack(alignment: .top, spacing: 0) {

                // Avg arrow score
                VStack(alignment: .leading, spacing: 2) {
                    Text(scoreString)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                        .contentTransition(.numericText())
                    Text("avg / arrow")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // X rate + session count
                VStack(alignment: .trailing, spacing: 10) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f%% X", overview.xPercentage))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(overview.xPercentage >= 50 ? Color.appAccent : .primary)
                            .contentTransition(.numericText())
                        Text("X rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(overview.sessionCount)")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                        Text("sessions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
                    overview.avgArrowScore >= 10 ? Color.appAccent.opacity(0.4) : Color.appBorder,
                    lineWidth: 1.5
                )
        )
        .animation(.easeInOut(duration: 0.3), value: overview.avgArrowScore)
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
        period: .week,
        sessionCount: 5,
        avgArrowScore: 10.7,
        xPercentage: 72,
        suggestions: AnalyticsSuggestion.mockAllSuggestions
    )

    static let mockMidScore = AnalyticsOverview(
        period: .twoWeeks,
        sessionCount: 3,
        avgArrowScore: 9.3,
        xPercentage: 28,
        suggestions: []
    )

    static let mockLowScore = AnalyticsOverview(
        period: .month,
        sessionCount: 1,
        avgArrowScore: 7.8,
        xPercentage: 5,
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
            rearStabSide: RearStabSide.none, rearStabWeight: 0, rearStabVertAngle: 0, rearStabHorizAngle: 0
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
            rearStabSide: RearStabSide.none, rearStabWeight: 0, rearStabVertAngle: 0, rearStabHorizAngle: 0
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

    /// Parallel avg-arrow-score values for the five mock configs (6–11 scale).
    static let mockScores: [Double] = [7.8, 8.5, 9.6, 9.2, 10.5]
}
