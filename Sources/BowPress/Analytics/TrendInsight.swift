import Foundation

/// Client-synthesized insight used by `LocalAnalyticsEngine.multiSessionInsights()`.
/// Wave 2 render path routes server-side `TrendFinding` through the new
/// trend-analysis ledger; client-generated `TrendInsight` values feed a
/// fallback pipeline that can still be materialized when offline.
///
/// Originally declared inside the deleted `AnalyticsTrendInsightsSection`.
/// Preserved here so `LocalAnalyticsEngine` still compiles and so the
/// `AnalyticsViewModel.extraInsights` bucket remains a source of offline
/// fallbacks for a future Wave 2.5 card.
struct TrendInsight: Identifiable {
    let id: String
    let icon: String
    let headline: String
    let detail: String
    let kind: Kind

    enum Kind { case positive, negative, neutral, info }
}
