import Foundation

// Spec §Stage 5 — Qualitative Correlation output. Server computes per-feel-tag
// score deltas across a bow's sessions and stores them; iOS fetches a list and
// renders them in the Analytics tab.
struct TagCorrelation: Codable, Identifiable {
    var bowId: String
    var userId: String
    var tag: String
    var taggedSessionCount: Int
    var untaggedSessionCount: Int
    var avgScoreTagged: Double?
    var avgScoreUntagged: Double?
    var scoreDelta: Double?
    var strength: Strength
    var updatedAt: Date

    var id: String { "\(bowId)-\(tag)" }

    enum Strength: String, Codable {
        case weak, moderate, strong
    }

    enum CodingKeys: String, CodingKey {
        case bowId = "bow_id"
        case userId = "user_id"
        case tag
        case taggedSessionCount = "tagged_session_count"
        case untaggedSessionCount = "untagged_session_count"
        case avgScoreTagged = "avg_score_tagged"
        case avgScoreUntagged = "avg_score_untagged"
        case scoreDelta = "score_delta"
        case strength
        case updatedAt = "updated_at"
    }
}
