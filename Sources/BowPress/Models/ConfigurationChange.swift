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
    /// Populated by the analytics pipeline (spec §Stage 4). nil until at least one
    /// scoring pass has run against both sides of this change.
    var impact: ChangeImpactCard?

    struct FieldChange: Codable {
        var field: String
        var fromValue: String
        var toValue: String

        /// Decode fromValue/toValue as either string or number — backend emits whichever
        /// matches the underlying config field type.
        enum CodingKeys: String, CodingKey { case field, fromValue, toValue }

        init(field: String, fromValue: String, toValue: String) {
            self.field = field
            self.fromValue = fromValue
            self.toValue = toValue
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            field = try c.decode(String.self, forKey: .field)
            fromValue = FieldChange.decodeStringOrNumber(container: c, key: .fromValue)
            toValue = FieldChange.decodeStringOrNumber(container: c, key: .toValue)
        }

        private static func decodeStringOrNumber(
            container: KeyedDecodingContainer<CodingKeys>,
            key: CodingKeys
        ) -> String {
            if let s = try? container.decode(String.self, forKey: key) { return s }
            if let d = try? container.decode(Double.self, forKey: key) {
                // Render integer-valued doubles as integers for display
                return d == d.rounded() ? String(Int(d)) : String(format: "%g", d)
            }
            if let i = try? container.decode(Int.self, forKey: key) { return String(i) }
            return ""
        }
    }
}

struct ChangeImpactCard: Codable {
    var scoreBefore: Double?
    var scoreAfter: Double?
    var scoreDelta: Double?
    var classification: Classification
    var feelTagsBefore: [String]
    var feelTagsAfter: [String]

    enum Classification: String, Codable {
        case clean, compound
    }
}
