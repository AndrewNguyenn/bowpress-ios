import Foundation

struct AnalyticsSuggestion: Identifiable, Codable {
    var id: String
    var bowId: String
    var createdAt: Date
    var parameter: String
    var suggestedValue: String
    var currentValue: String
    var reasoning: String
    var confidence: Double        // 0.0–1.0
    var qualifier: String?
    var wasRead: Bool
    var wasDismissed: Bool = false
    var deliveryType: DeliveryType

    enum DeliveryType: String, Codable {
        case push, inApp, reinforcement
    }

    enum CodingKeys: String, CodingKey {
        case id, bowId, createdAt, parameter, suggestedValue, currentValue
        case reasoning, confidence, qualifier, wasRead, wasDismissed, deliveryType
    }

    init(
        id: String, bowId: String, createdAt: Date, parameter: String,
        suggestedValue: String, currentValue: String, reasoning: String,
        confidence: Double, qualifier: String? = nil, wasRead: Bool,
        wasDismissed: Bool = false, deliveryType: DeliveryType
    ) {
        self.id = id; self.bowId = bowId; self.createdAt = createdAt
        self.parameter = parameter; self.suggestedValue = suggestedValue
        self.currentValue = currentValue; self.reasoning = reasoning
        self.confidence = confidence; self.qualifier = qualifier
        self.wasRead = wasRead; self.wasDismissed = wasDismissed
        self.deliveryType = deliveryType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        bowId = try c.decode(String.self, forKey: .bowId)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        parameter = try c.decode(String.self, forKey: .parameter)
        suggestedValue = try c.decode(String.self, forKey: .suggestedValue)
        currentValue = try c.decode(String.self, forKey: .currentValue)
        reasoning = try c.decode(String.self, forKey: .reasoning)
        confidence = try c.decode(Double.self, forKey: .confidence)
        qualifier = try c.decodeIfPresent(String.self, forKey: .qualifier)
        wasRead = try c.decode(Bool.self, forKey: .wasRead)
        wasDismissed = try c.decodeIfPresent(Bool.self, forKey: .wasDismissed) ?? false
        deliveryType = try c.decode(DeliveryType.self, forKey: .deliveryType)
    }
}
