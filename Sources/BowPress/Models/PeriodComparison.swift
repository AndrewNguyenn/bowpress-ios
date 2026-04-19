import Foundation

struct PeriodSlice: Codable {
    let label: String
    let plots: [ArrowPlot]
    let avgArrowScore: Double
    let xPercentage: Double
    let sessionCount: Int
    let config: BowConfiguration?
}

struct PeriodComparison: Codable {
    let period: AnalyticsPeriod
    let current: PeriodSlice
    let previous: PeriodSlice
}
