import Foundation

struct ArrowPlot: Identifiable, Codable, Equatable {
    var id: String
    var sessionId: String
    var bowConfigId: String
    var arrowConfigId: String
    var ring: Int                 // 8, 9, 10, 11 = X
    var zone: Zone
    var plotX: Double?            // normalized position from center (-1…1), nil for legacy data
    var plotY: Double?
    var endId: String?
    var shotAt: Date
    var excluded: Bool
    var notes: String?

    enum Zone: String, Codable, CaseIterable {
        case center = "CENTER"
        case n = "N", ne = "NE", e = "E", se = "SE"
        case s = "S", sw = "SW", w = "W", nw = "NW"
    }
}
