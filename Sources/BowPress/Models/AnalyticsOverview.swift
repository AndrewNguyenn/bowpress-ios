import Foundation

struct AnalyticsOverview: Codable {
    var period: AnalyticsPeriod
    var sessionCount: Int
    var avgArrowScore: Double
    var xPercentage: Double
    var suggestions: [AnalyticsSuggestion]
}
