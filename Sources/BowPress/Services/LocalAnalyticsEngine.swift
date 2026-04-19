import Foundation

@MainActor
final class LocalAnalyticsEngine {
    private let store: LocalStore

    init(store: LocalStore) {
        self.store = store
    }

    // MARK: - Overview

    func overview(period: AnalyticsPeriod) throws -> AnalyticsOverview {
        let periodStart = period.startDate
        let sessions = try store.fetchSessions().filter { $0.startedAt >= periodStart }
        let arrows = try store.fetchArrows(since: periodStart)
            .filter { !$0.excluded }
        let sessionIds = Set(sessions.map(\.id))
        let periodArrows = arrows.filter { sessionIds.contains($0.sessionId) }
        return AnalyticsOverview(
            period: period,
            sessionCount: sessions.count,
            avgArrowScore: avgScore(periodArrows),
            xPercentage: xRate(periodArrows) * 100,
            suggestions: []
        )
    }

    // MARK: - Comparison

    func comparison(period: AnalyticsPeriod) throws -> PeriodComparison {
        let now = Date()
        let duration = period.duration
        let currentStart = now.addingTimeInterval(-duration)
        let previousStart = now.addingTimeInterval(-duration * 2)

        let allSessions = try store.fetchSessions()
        let allArrows = try store.fetchAllArrows().filter { !$0.excluded }

        let currentSessions = allSessions.filter { $0.startedAt >= currentStart }
        let previousSessions = allSessions.filter { $0.startedAt >= previousStart && $0.startedAt < currentStart }

        let currentSlice = slice(
            label: "Last \(period.label)",
            sessions: currentSessions,
            arrows: allArrows,
            period: period
        )
        let previousSlice = slice(
            label: "Previous \(period.label)",
            sessions: previousSessions,
            arrows: allArrows,
            period: period
        )
        return PeriodComparison(period: period, current: currentSlice, previous: previousSlice)
    }

    private func slice(label: String, sessions: [ShootingSession], arrows: [ArrowPlot], period: AnalyticsPeriod) -> PeriodSlice {
        let ids = Set(sessions.map(\.id))
        let plots = arrows.filter { ids.contains($0.sessionId) }
        let activeConfigId = sessions.max(by: { $0.startedAt < $1.startedAt })?.bowConfigId
        let activeConfig: BowConfiguration? = activeConfigId.flatMap { cid in
            try? store.fetchConfigurations(bowId: sessions.first?.bowId ?? "")
                .first { $0.id == cid }
        }
        return PeriodSlice(
            label: label,
            plots: plots,
            avgArrowScore: avgScore(plots),
            xPercentage: xRate(plots) * 100,
            sessionCount: sessions.count,
            config: activeConfig
        )
    }

    // MARK: - Multi-session insights

    func multiSessionInsights() throws -> [TrendInsight] {
        let sessions = try store.fetchSessions()
            .sorted { $0.startedAt < $1.startedAt }
        guard sessions.count >= 2 else { return [] }

        let allArrows = try store.fetchAllArrows().filter { !$0.excluded }
        var insights: [TrendInsight] = []

        if let drift = driftInsight(sessions: sessions, arrows: allArrows) {
            insights.append(drift)
        }
        if let tuning = postTuningInsight(sessions: sessions, arrows: allArrows) {
            insights.append(tuning)
        }
        if let condition = conditionCorrelationInsight(sessions: sessions, arrows: allArrows) {
            insights.append(condition)
        }
        if let plateau = plateauInsight(sessions: sessions, arrows: allArrows) {
            insights.append(plateau)
        }
        return insights
    }

    // MARK: - Insight: multi-session drift

    private func driftInsight(sessions: [ShootingSession], arrows: [ArrowPlot]) -> TrendInsight? {
        let recent = Array(sessions.suffix(6))
        guard recent.count >= 4 else { return nil }

        let arrowMap = Dictionary(grouping: arrows, by: \.sessionId)
        let centroids: [(x: Double, y: Double)] = recent.compactMap { session in
            let plots = arrowMap[session.id] ?? []
            let real = plots.compactMap { p -> (Double, Double)? in
                guard let x = p.plotX, let y = p.plotY else { return nil }
                return (x, y)
            }
            guard real.count >= 3 else { return nil }
            return (x: real.map(\.0).reduce(0, +) / Double(real.count),
                    y: real.map(\.1).reduce(0, +) / Double(real.count))
        }
        guard centroids.count >= 4 else { return nil }

        let meanX = centroids.map(\.x).reduce(0, +) / Double(centroids.count)
        let meanY = centroids.map(\.y).reduce(0, +) / Double(centroids.count)
        let meanDist = hypot(meanX, meanY)
        guard meanDist > 0.03 else { return nil }

        let dominantXSign = meanX >= 0 ? 1.0 : -1.0
        let dominantYSign = meanY >= 0 ? 1.0 : -1.0
        let agreeing = centroids.filter {
            ($0.x == 0 || ($0.x > 0) == (dominantXSign > 0)) &&
            ($0.y == 0 || ($0.y > 0) == (dominantYSign > 0))
        }
        guard agreeing.count >= 4 else { return nil }

        let distMM = String(format: "%.1f", meanDist * mmPerNorm)
        let dir = driftDirection(x: meanX, y: meanY)
        let param = driftParameterHint(x: meanX, y: meanY)
        return TrendInsight(
            id: "multi_session_drift",
            icon: "scope",
            headline: "Group center ~\(distMM)mm \(dir) across \(agreeing.count) sessions",
            detail: "Your group center has been consistently \(dir) of target center. \(param) Check whether this drift coincides with a recent config change or form pattern.",
            kind: .neutral
        )
    }

    private func driftDirection(x: Double, y: Double) -> String {
        let adx = abs(x), ady = abs(y)
        if ady > adx * 1.7 { return y > 0 ? "north (high)" : "south (low)" }
        if adx > ady * 1.7 { return x > 0 ? "right" : "left" }
        let v = y > 0 ? "high" : "low"; let h = x > 0 ? "right" : "left"
        return "\(v)-\(h)"
    }

    private func driftParameterHint(x: Double, y: Double) -> String {
        let adx = abs(x), ady = abs(y)
        if ady > adx * 1.7 {
            return y > 0
                ? "Persistent high drift often points to nocking point too low or peep height too high."
                : "Persistent low drift often points to nocking point too high."
        }
        return "Persistent horizontal drift often points to rest horizontal position or cant."
    }

    // MARK: - Insight: post-tuning effect

    private func postTuningInsight(sessions: [ShootingSession], arrows: [ArrowPlot]) -> TrendInsight? {
        guard sessions.count >= 4 else { return nil }
        let arrowMap = Dictionary(grouping: arrows, by: \.sessionId)

        var changeIdx: Int?
        for i in 1..<sessions.count {
            if sessions[i].bowConfigId != sessions[i - 1].bowConfigId {
                changeIdx = i
            }
        }
        guard let idx = changeIdx else { return nil }

        let pre = Array(sessions[max(0, idx - 2)..<idx])
        let post = Array(sessions[idx...])
        guard pre.count >= 1, post.count >= 2 else { return nil }

        let preScores = pre.map { avgScore(arrowMap[$0.id] ?? []) }.filter { $0 > 0 }
        let postScores = post.map { avgScore(arrowMap[$0.id] ?? []) }.filter { $0 > 0 }
        guard !preScores.isEmpty, !postScores.isEmpty else { return nil }

        let preMean = preScores.reduce(0, +) / Double(preScores.count)
        let postFirst = postScores.prefix(2).reduce(0, +) / Double(min(2, postScores.count))
        let postLast = postScores.last ?? postFirst

        if postFirst < preMean - 0.2 && postLast >= preMean - 0.1 {
            let n = postScores.count
            return TrendInsight(
                id: "post_tuning_effect",
                icon: "wrench.and.screwdriver",
                headline: "Setup dialing in after recent config change",
                detail: "Scores dipped for \(n > 2 ? "the first few" : "1–2") sessions after your last tuning change, then recovered to \(String(format: "%.1f", postLast)) — above your pre-change average of \(String(format: "%.1f", preMean)). The adjustment is holding up.",
                kind: .positive
            )
        }
        if postFirst < preMean - 0.2 && postLast < preMean - 0.2 {
            return TrendInsight(
                id: "post_tuning_effect",
                icon: "wrench.and.screwdriver",
                headline: "Scores haven't recovered since last config change",
                detail: "Average score since your last tuning change (\(String(format: "%.1f", postFirst))) remains below your pre-change baseline (\(String(format: "%.1f", preMean))). Consider reverting or logging more sessions before drawing conclusions.",
                kind: .negative
            )
        }
        return nil
    }

    // MARK: - Insight: condition correlation

    private func conditionCorrelationInsight(sessions: [ShootingSession], arrows: [ArrowPlot]) -> TrendInsight? {
        guard sessions.count >= 6 else { return nil }
        let arrowMap = Dictionary(grouping: arrows, by: \.sessionId)
        var allTags = Set<String>()
        sessions.forEach { allTags.formUnion($0.feelTags) }

        var best: (tag: String, delta: Double, taggedMean: Double, n: Int)?
        for tag in allTags {
            let tagged = sessions.filter { $0.feelTags.contains(tag) }
            let untagged = sessions.filter { !$0.feelTags.contains(tag) }
            guard tagged.count >= 3, untagged.count >= 3 else { continue }

            let taggedScores = tagged.map { avgScore(arrowMap[$0.id] ?? []) }.filter { $0 > 0 }
            let untaggedScores = untagged.map { avgScore(arrowMap[$0.id] ?? []) }.filter { $0 > 0 }
            guard !taggedScores.isEmpty, !untaggedScores.isEmpty else { continue }

            let tm = taggedScores.reduce(0, +) / Double(taggedScores.count)
            let um = untaggedScores.reduce(0, +) / Double(untaggedScores.count)
            let delta = abs(tm - um)
            if delta > 0.4, best == nil || delta > best!.delta {
                best = (tag: tag, delta: delta, taggedMean: tm, n: tagged.count)
            }
        }
        guard let b = best else { return nil }
        let lower = b.taggedMean < (b.taggedMean + b.delta) ? "lower" : "higher"
        return TrendInsight(
            id: "condition_correlation_\(b.tag)",
            icon: "tag",
            headline: "Sessions tagged '\(b.tag)' average \(String(format: "%.1f", b.delta))pts \(lower)",
            detail: "Across \(b.n) sessions tagged '\(b.tag)', average arrow score is \(String(format: "%.1f", b.delta))pts \(lower) than untagged sessions. If '\(b.tag)' reflects a form or equipment issue, addressing it directly may have more impact than further tuning.",
            kind: .neutral
        )
    }

    // MARK: - Insight: plateau detection

    private func plateauInsight(sessions: [ShootingSession], arrows: [ArrowPlot]) -> TrendInsight? {
        guard sessions.count >= 8 else { return nil }
        let arrowMap = Dictionary(grouping: arrows, by: \.sessionId)
        let recent = Array(sessions.suffix(10))
        let scores = recent.map { avgScore(arrowMap[$0.id] ?? []) }.filter { $0 > 0 }
        guard scores.count >= 8 else { return nil }

        let mean = scores.reduce(0, +) / Double(scores.count)
        let variance = scores.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(scores.count)
        let stdDev = sqrt(variance)
        guard stdDev < 0.15 else { return nil }

        return TrendInsight(
            id: "plateau",
            icon: "chart.bar.fill",
            headline: "Score variance tight at ±\(String(format: "%.2f", stdDev))pts over \(scores.count) sessions",
            detail: "Your scores have been stable around \(String(format: "%.1f", mean)) with very little variation. This is a local ceiling — consistent form is good, but if you want to improve, a deliberate equipment change or targeted drill is more likely to move the needle than continued repetition at the current setup.",
            kind: .info
        )
    }

    // MARK: - Helpers

    private let mmPerNorm: Double = 20.0 / (119.0 / 735.0)

    private func avgScore(_ plots: [ArrowPlot]) -> Double {
        let active = plots.filter { !$0.excluded }
        guard !active.isEmpty else { return 0 }
        return Double(active.map(\.ring).reduce(0, +)) / Double(active.count)
    }

    private func xRate(_ plots: [ArrowPlot]) -> Double {
        guard !plots.isEmpty else { return 0 }
        return Double(plots.filter { $0.ring == 11 }.count) / Double(plots.count)
    }
}

// MARK: - AnalyticsPeriod helpers

private extension AnalyticsPeriod {
    var duration: TimeInterval {
        switch self {
        case .threeDays:   return 3 * 86400
        case .week:        return 7 * 86400
        case .twoWeeks:    return 14 * 86400
        case .month:       return 30 * 86400
        case .threeMonths: return 90 * 86400
        case .sixMonths:   return 180 * 86400
        case .year:        return 365 * 86400
        }
    }

    var startDate: Date {
        Date().addingTimeInterval(-duration)
    }
}
