import Foundation

/// Overview payload returned by `GET /analytics/overview`.
///
/// Wave 2 extended the shape with `groupSigma`, `sparkline`, and
/// `datasetSummary`. All three are optional so pre-Wave-2 server responses
/// (and the Wave-1 `LocalAnalyticsEngine.overview()` which still emits only
/// the original four fields) decode without breaking.
struct AnalyticsOverview: Codable {
    var period: AnalyticsPeriod
    var sessionCount: Int
    var avgArrowScore: Double
    var xPercentage: Double
    var suggestions: [AnalyticsSuggestion]
    // Wave 2 additions — all nullable so older responses decode cleanly.
    var groupSigma: Double?
    var sparkline: [SparklinePoint]?
    var datasetSummary: DatasetSummary?

    enum CodingKeys: String, CodingKey {
        case period, sessionCount, avgArrowScore, xPercentage, suggestions
        case groupSigma, sparkline, datasetSummary
    }

    init(
        period: AnalyticsPeriod,
        sessionCount: Int,
        avgArrowScore: Double,
        xPercentage: Double,
        suggestions: [AnalyticsSuggestion],
        groupSigma: Double? = nil,
        sparkline: [SparklinePoint]? = nil,
        datasetSummary: DatasetSummary? = nil
    ) {
        self.period = period
        self.sessionCount = sessionCount
        self.avgArrowScore = avgArrowScore
        self.xPercentage = xPercentage
        self.suggestions = suggestions
        self.groupSigma = groupSigma
        self.sparkline = sparkline
        self.datasetSummary = datasetSummary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        period = try c.decode(AnalyticsPeriod.self, forKey: .period)
        sessionCount = try c.decode(Int.self, forKey: .sessionCount)
        avgArrowScore = try c.decode(Double.self, forKey: .avgArrowScore)
        xPercentage = try c.decode(Double.self, forKey: .xPercentage)
        suggestions = try c.decodeIfPresent([AnalyticsSuggestion].self, forKey: .suggestions) ?? []
        groupSigma = try c.decodeIfPresent(Double.self, forKey: .groupSigma)
        sparkline = try c.decodeIfPresent([SparklinePoint].self, forKey: .sparkline)
        datasetSummary = try c.decodeIfPresent(DatasetSummary.self, forKey: .datasetSummary)
    }
}

/// One point in the score timeline / overview sparkline.
struct SparklinePoint: Codable, Equatable {
    let at: Date
    let avg: Double
}

/// Meta describing the rows analytics worked from. Used by the footnote grid.
struct DatasetSummary: Codable, Equatable {
    let arrows: Int
    let bowLabel: String?
    let arrowLabel: String?
    let sinceDate: Date?
}
