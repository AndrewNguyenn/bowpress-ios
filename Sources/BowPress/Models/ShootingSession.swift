import Foundation

struct ShootingSession: Identifiable, Codable, Equatable {
    var id: String
    var bowId: String
    var bowConfigId: String
    var arrowConfigId: String
    var startedAt: Date
    var endedAt: Date?
    var notes: String
    var feelTags: [String]
    var conditions: SessionConditions?
    var arrowCount: Int
    var ends: [SessionEnd]?
    var arrows: [ArrowPlot]?
}

struct SessionConditions: Codable, Equatable {
    var windSpeed: Double?
    var tempF: Double?
    var lighting: String?
}
