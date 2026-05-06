import Foundation

/// A calibrated sight reading at a specific distance for a specific arrow.
/// Per-archer (`userId`) and per-arrow (`arrowId`); intentionally not keyed
/// on bow configuration — a tune change invalidates marks but per-arrow
/// keying is the closest meaningful axis archers naturally swap on.
///
/// `mark` is numeric so the suggester can interpolate. Multi-pin sights
/// (where the mark is a discrete pin label, not a number) are out of scope
/// for v1.
struct SightMark: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var userId: String
    var arrowId: String
    var distance: Double
    var distanceUnit: DistanceUnit
    var mark: Double
    var note: String?
    var isSuggestion: Bool
    var createdAt: Date
    var updatedAt: Date
}

enum DistanceUnit: String, Codable, CaseIterable, Hashable {
    case yards
    case meters

    /// Conversion to meters for unit-normalized comparisons (e.g. the
    /// "20 yard spread" gating rule has to work whether marks are stored
    /// in yards or meters).
    var metersPerUnit: Double {
        switch self {
        case .yards:  return 0.9144
        case .meters: return 1.0
        }
    }

    /// Short suffix used in display (`"yd"` / `"m"`).
    var shortLabel: String {
        switch self {
        case .yards:  return "yd"
        case .meters: return "m"
        }
    }

    /// The unit a given UnitSystem prefers for distance.
    static func preferred(for system: UnitSystem) -> DistanceUnit {
        system == .imperial ? .yards : .meters
    }
}

extension SightMark {
    /// Distance expressed in meters, used for unit-normalized math
    /// (sorting, spread checks, fitting). Never shown to the user — that
    /// always renders in the archer's preferred unit.
    var distanceInMeters: Double {
        distance * distanceUnit.metersPerUnit
    }
}
