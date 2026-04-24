import Foundation

/// Aggregate for one half of a period-over-period comparison. Wave 2 added the
/// optional centroid + sigma ellipse so the Analytics impact-map overlay can
/// plot "previous vs now" without a separate endpoint.
struct PeriodSlice: Codable {
    let label: String
    let plots: [ArrowPlot]
    let avgArrowScore: Double
    let xPercentage: Double
    let sessionCount: Int
    let config: BowConfiguration?
    // Wave 2 — optional so pre-Wave-2 servers decode cleanly.
    let centroid: Centroid?
    let sigma: SigmaEllipse?

    enum CodingKeys: String, CodingKey {
        case label, plots, avgArrowScore, xPercentage, sessionCount, config
        case centroid, sigma
    }

    init(
        label: String,
        plots: [ArrowPlot],
        avgArrowScore: Double,
        xPercentage: Double,
        sessionCount: Int,
        config: BowConfiguration?,
        centroid: Centroid? = nil,
        sigma: SigmaEllipse? = nil
    ) {
        self.label = label
        self.plots = plots
        self.avgArrowScore = avgArrowScore
        self.xPercentage = xPercentage
        self.sessionCount = sessionCount
        self.config = config
        self.centroid = centroid
        self.sigma = sigma
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decode(String.self, forKey: .label)
        plots = try c.decodeIfPresent([ArrowPlot].self, forKey: .plots) ?? []
        avgArrowScore = try c.decode(Double.self, forKey: .avgArrowScore)
        xPercentage = try c.decode(Double.self, forKey: .xPercentage)
        sessionCount = try c.decode(Int.self, forKey: .sessionCount)
        config = try c.decodeIfPresent(BowConfiguration.self, forKey: .config)
        centroid = try c.decodeIfPresent(Centroid.self, forKey: .centroid)
        sigma = try c.decodeIfPresent(SigmaEllipse.self, forKey: .sigma)
    }
}

struct PeriodComparison: Codable {
    let period: AnalyticsPeriod
    let current: PeriodSlice
    let previous: PeriodSlice
    // Wave 2 — optional shift vector describing the movement of the group
    // centroid between periods.
    let shift: ShiftVector?

    enum CodingKeys: String, CodingKey {
        case period, current, previous, shift
    }

    init(
        period: AnalyticsPeriod,
        current: PeriodSlice,
        previous: PeriodSlice,
        shift: ShiftVector? = nil
    ) {
        self.period = period
        self.current = current
        self.previous = previous
        self.shift = shift
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        period = try c.decode(AnalyticsPeriod.self, forKey: .period)
        current = try c.decode(PeriodSlice.self, forKey: .current)
        previous = try c.decode(PeriodSlice.self, forKey: .previous)
        shift = try c.decodeIfPresent(ShiftVector.self, forKey: .shift)
    }
}

/// Normalized centroid on the target face. Values are in the same coordinate
/// space as `ArrowPlot.plotX` / `plotY` (roughly -1...1 across the face).
struct Centroid: Codable, Equatable {
    let x: Double
    let y: Double
}

/// 1σ dispersion ellipse. `major` / `minor` are in the same normalized units
/// as the centroid; `rotationDeg` is the ellipse angle in degrees.
struct SigmaEllipse: Codable, Equatable {
    let major: Double
    let minor: Double
    let rotationDeg: Double
}

/// Shift vector summarising the move from prev → current centroid, in mm on
/// the physical target face plus a pre-rendered human-readable description.
struct ShiftVector: Codable, Equatable {
    let dxMm: Double
    let dyMm: Double
    let direction: String
    let description: String
}
