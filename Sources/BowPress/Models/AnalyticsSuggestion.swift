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
    var deliveryType: DeliveryType

    enum DeliveryType: String, Codable {
        case push, inApp, reinforcement
    }
}
