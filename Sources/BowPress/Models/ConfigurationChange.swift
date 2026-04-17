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

    struct FieldChange: Codable {
        var field: String
        var fromValue: String
        var toValue: String
    }
}
