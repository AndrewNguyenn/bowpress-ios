import Foundation

struct ConfigurationChange: Identifiable, Codable {
    var id: String
    var bowId: String
    var fromConfigId: String
    var toConfigId: String
    var createdAt: Date
    var changedFields: [FieldChange]
    var changeCount: Int
    var notes: String?
    // TODO: real implementation lands in follow-up
    var impact: ChangeImpactCard?

    struct FieldChange: Codable {
        var field: String
        var fromValue: String
        var toValue: String
    }
}

// TODO: real implementation lands in follow-up
struct ChangeImpactCard: Codable {
    var scoreBefore: Double?
    var scoreAfter: Double?
    var scoreDelta: Double?
    var classification: Classification
    var feelTagsBefore: [String] = []
    var feelTagsAfter: [String] = []

    enum Classification: String, Codable {
        case clean, compound
    }
}
