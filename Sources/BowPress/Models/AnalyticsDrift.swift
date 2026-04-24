import Foundation

/// Parameter-drift payload returned by `GET /analytics/drift`. Powers the
/// "Parameter drift" table — one row per tuning parameter with before/now
/// values, a pre-computed delta string, and a sample size `n`.
struct DriftResponse: Decodable {
    let period: AnalyticsPeriod
    let rows: [DriftRow]
}

struct DriftRow: Decodable {
    /// Canonical parameter key — matches `AnalyticsSuggestion.parameter`, i.e.
    /// `restVertical`, `peepHeight`, `dLoopLength`, etc.
    let parameter: String
    /// Display name the server emits (may differ from the default camelCase
    /// → Title-Case mapping for localized or Japanese-palette copy).
    let label: String
    /// Unit suffix the view appends to the before/now cells if the server
    /// didn't already include it in the pre-formatted strings.
    let unit: String
    /// Pre-formatted before/now/delta values. Strings so fractions like
    /// "+3⁄16″" survive the wire without a custom serializer.
    let before: String?
    let now: String?
    let delta: String?
    let deltaTone: DeltaTone
    /// Sample size — arrows (not sessions) that informed this row.
    let n: Int
}

/// Direction token controlling the delta cell's color. Matches the server
/// enum verbatim.
enum DeltaTone: String, Decodable {
    case up, down, flat
}
