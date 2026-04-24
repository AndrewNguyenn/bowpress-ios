import Foundation

/// Distance from the shooter to the target. Optional on `ShootingSession` —
/// existing sessions stay nil and the analytics filter only includes a session
/// in a specific-distance view when the value matches exactly.
enum ShootingDistance: String, Codable, CaseIterable, Hashable {
    case twentyYards   = "20yd"
    case fiftyMeters   = "50m"
    case seventyMeters = "70m"

    var label: String { rawValue }

    /// Short context label rendered as the picker-row subtitle.
    var subtitle: String {
        switch self {
        case .twentyYards:   return "Indoor / 3D"
        case .fiftyMeters:   return "WA outdoor — compound, barebow"
        case .seventyMeters: return "WA outdoor — recurve"
        }
    }
}
