import Foundation

#if DEBUG

// MARK: - MockAnalyticsWave2
//
// Fixtures for the Wave-2 analytics endpoints (timeline / drift / trends) and
// the extended overview / comparison fields. Mirrors the shapes Agent A1 is
// wiring on the API side so previews + DEBUG builds render the new Analytics
// screen with plausible values when offline.

enum MockAnalyticsWave2 {

    // MARK: - Timeline

    static func timeline(period: AnalyticsPeriod) -> TimelineResponse {
        let points = sparklinePoints(period: period)
        let values = points.map(\.avg)
        let lo = values.min() ?? 9.0
        let hi = values.max() ?? 11.0
        let mean = values.reduce(0, +) / Double(max(values.count, 1))
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(max(values.count, 1))
        let sigma = sqrt(variance)
        let mapped = points.enumerated().map { idx, p in
            TimelinePoint(
                sessionId: "mock_s\(idx + 1)",
                at: p.at,
                avg: p.avg,
                isLatest: idx == points.count - 1
            )
        }
        return TimelineResponse(
            period: period,
            range: TimelineRange(min: lo, max: hi, sigma: sigma),
            points: mapped
        )
    }

    /// Reused by `overview.sparkline` so the bars and the timeline agree.
    static func sparklinePoints(period: AnalyticsPeriod) -> [SparklinePoint] {
        // Mild upward trend, last point as the best — matches the design
        // reference which highlights the most recent reading as the ceiling.
        let baseline: [Double] = [9.2, 9.6, 9.3, 10.0, 9.8, 10.2, 10.1, 10.5, 10.4, 10.7]
        let now = Date()
        let step: TimeInterval
        switch period {
        case .threeDays: step = 86_400 / 3
        case .week:      step = 86_400
        case .twoWeeks:  step = 86_400 * 1.2
        case .month:     step = 86_400 * 2.5
        default:         step = 86_400 * 4
        }
        return baseline.enumerated().map { idx, avg in
            let at = now.addingTimeInterval(-step * Double(baseline.count - idx - 1))
            return SparklinePoint(at: at, avg: avg)
        }
    }

    // MARK: - Drift

    static func drift(period: AnalyticsPeriod) -> DriftResponse {
        DriftResponse(
            period: period,
            rows: [
                DriftRow(
                    parameter: "nockingHeight", label: "Nocking height", unit: "\"",
                    before: "0\"", now: "+3⁄16\"", delta: "+3⁄16",
                    deltaTone: .up, n: 42
                ),
                DriftRow(
                    parameter: "drawLength", label: "Draw length", unit: "\"",
                    before: "29.0\"", now: "28.5\"", delta: "−0.5",
                    deltaTone: .down, n: 38
                ),
                DriftRow(
                    parameter: "restVertical", label: "Rest vertical", unit: "\"",
                    before: "13⁄16\"", now: "13⁄16\"", delta: "—",
                    deltaTone: .flat, n: 58
                ),
                DriftRow(
                    parameter: "topCableTwists", label: "Top cable twists", unit: "",
                    before: "0", now: "+2", delta: "+2",
                    deltaTone: .up, n: 24
                ),
                DriftRow(
                    parameter: "peepHeight", label: "Peep height", unit: "\"",
                    before: "4.25\"", now: "4.25\"", delta: "—",
                    deltaTone: .flat, n: 58
                ),
            ]
        )
    }

    // MARK: - Trends

    static func trends(period: AnalyticsPeriod) -> TrendsResponse {
        TrendsResponse(
            period: period,
            findings: [
                TrendFinding(
                    id: "f1",
                    index: 1,
                    title: "Group shift — drifting high",
                    metric: TrendMetric(text: "·6.6mm ↑ N of X", tone: .neutral),
                    body: "Shots consistently land north of center. At this distance a 6.6 mm drift is meaningful and worth acting on before it settles into muscle memory.",
                    cues: "likely causes · **peep height** · **nocking point** · anchor drift",
                    badge: .watch
                ),
                TrendFinding(
                    id: "f2",
                    index: 2,
                    title: "10-ring+ rate",
                    metric: TrendMetric(text: "100% → 100%", tone: .positive),
                    body: "Every arrow this period landed in the 10-ring or better. Holding at the ceiling; tighter groupings at the top of the scoring zone suggest improving consistency.",
                    cues: "sample · **138 arrows** · 4 sessions",
                    badge: .gain
                ),
                TrendFinding(
                    id: "f3",
                    index: 3,
                    title: "X-ring rate",
                    metric: TrendMetric(text: "47% → 56%", tone: .positive),
                    body: "X-ring hits up nine points. At 50 %+ you are shooting at a competitive indoor standard — continue the current setup through the end of the week.",
                    cues: "benchmark · **≥ 50%** indoor competitive",
                    badge: .gain
                ),
                TrendFinding(
                    id: "f4",
                    index: 4,
                    title: "Session volume",
                    metric: TrendMetric(text: "4 sessions · +3 vs last", tone: .positive),
                    body: "Range time tripled this period. Consistent volume is one of the strongest predictors of score improvement — keep the frequency up.",
                    cues: "cadence · **every other day** · holding",
                    badge: .gain
                ),
                TrendFinding(
                    id: "f5",
                    index: 5,
                    title: "Tuning change",
                    metric: TrendMetric(text: "effect still developing", tone: .neutral),
                    body: "A bow configuration change was made between periods. Scores shifted +0.1 pts. Give it a few more sessions before drawing conclusions — new setups often need time to fully dial in.",
                    cues: "change · **nocking +3⁄16″** · apr 21",
                    badge: .hold
                ),
                TrendFinding(
                    id: "f6",
                    index: 6,
                    title: "Feel tag correlation",
                    metric: TrendMetric(text: "\u{201C}consistent\u{201D} − 1.5 pts", tone: .negative),
                    body: "Sessions tagged \u{201C}consistent\u{201D} averaged 1.5 pts lower than untagged sessions. The self-assessment and the score are decoupling — worth examining what \u{201C}consistent\u{201D} feels like versus what it produces.",
                    cues: "sample · **12 tagged** vs 26 untagged",
                    badge: .watch
                ),
            ]
        )
    }

    // MARK: - Shift + centroids (overlay on the impact map)

    /// Previous-week centroid. Normalized (face-space) coords roughly in -1...1.
    static let previousCentroid = Centroid(x: -0.06, y: 0.04)
    /// Current-week centroid — slightly right and up, consistent with the
    /// reference HTML's "+8mm, −6mm" shift copy.
    static let currentCentroid = Centroid(x: 0.02, y: -0.02)

    static let previousSigma = SigmaEllipse(major: 0.16, minor: 0.12, rotationDeg: -18)
    static let currentSigma  = SigmaEllipse(major: 0.11, minor: 0.08, rotationDeg: 12)

    static let shiftVector = ShiftVector(
        dxMm: 8,
        dyMm: -6,
        direction: "right · up",
        description: "right · up · toward center"
    )

    // MARK: - Dataset summary (footnote grid)

    static func datasetSummary(bow: Bow?, arrow: ArrowConfiguration?) -> DatasetSummary {
        DatasetSummary(
            arrows: 138,
            bowLabel: bow.map { "\($0.name) · \($0.bowType.label.lowercased())" },
            arrowLabel: arrow.map { "\($0.label) \(String(format: "%.1f\"", $0.length))" },
            sinceDate: Date().addingTimeInterval(-86_400 * 3)
        )
    }
}

#endif
