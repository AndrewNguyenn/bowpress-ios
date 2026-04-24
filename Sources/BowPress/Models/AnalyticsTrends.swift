import Foundation

/// Trend analysis payload returned by `GET /analytics/trends`. Drives the
/// "Trend analysis" ledger above the suggestions section.
struct TrendsResponse: Decodable {
    let period: AnalyticsPeriod
    let findings: [TrendFinding]
}

struct TrendFinding: Decodable, Identifiable {
    let id: String
    let index: Int
    let title: String
    let metric: TrendMetric
    let body: String
    let cues: String?
    let badge: TrendBadge
}

/// Colored inline metric tag embedded in the title. Rendered as JetBrains Mono
/// in the view, colored per `tone`.
struct TrendMetric: Decodable {
    let text: String
    let tone: TrendTone
}

enum TrendTone: String, Decodable {
    case positive, negative, neutral
}

/// Right-aligned stamp on each trend row. Maps to `BPStamp.Tone.pine` (gain),
/// `.maple` (watch), `.stone` (hold) respectively.
enum TrendBadge: String, Decodable {
    case gain, watch, hold

    var label: String {
        switch self {
        case .gain:  return "Gain"
        case .watch: return "Watch"
        case .hold:  return "Hold"
        }
    }

    var stampTone: BPStamp.Tone {
        switch self {
        case .gain:  return .pine
        case .watch: return .maple
        case .hold:  return .stone
        }
    }
}
