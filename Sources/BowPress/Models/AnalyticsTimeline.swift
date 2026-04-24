import Foundation

/// Score timeline payload returned by `GET /analytics/timeline`. Powers the
/// "Score timeline" sparkline + the range/σ aside rendered above it.
struct TimelineResponse: Decodable {
    let period: AnalyticsPeriod
    let range: TimelineRange
    let points: [TimelinePoint]
}

/// Axis metadata — the top/middle/bottom axis labels on the sparkline use
/// `max`, the midpoint between min and max, and `min` respectively. `sigma`
/// is the session-to-session score standard deviation shown in the aside.
struct TimelineRange: Decodable {
    let min: Double
    let max: Double
    let sigma: Double
}

/// One session's rolled-up avg arrow score.
struct TimelinePoint: Decodable {
    let sessionId: String
    let at: Date
    let avg: Double
    let isLatest: Bool
}
