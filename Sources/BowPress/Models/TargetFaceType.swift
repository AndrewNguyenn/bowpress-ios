import Foundation

/// Which target face the archer is shooting at.
///
/// `sixRing` is the compound indoor-6 face (rings 6-X); `tenRing` is the standard
/// WA 10-ring face (rings 1-X). Raw values use snake_case so JSON stored today
/// keeps decoding stably even when the field is round-tripped to/from the API.
enum TargetFaceType: String, Codable, CaseIterable, Hashable {
    case sixRing = "six_ring"
    case tenRing = "ten_ring"

    var label: String {
        switch self {
        case .sixRing: return "6-Ring"
        case .tenRing: return "10-Ring"
        }
    }

    var setupSubtitle: String {
        switch self {
        case .sixRing: return "Compound inner · rings 6–X"
        case .tenRing: return "WA full face · rings 1–X"
        }
    }

    /// The sensible default face for a given bow style.
    /// Compound archers typically shoot the inner 6-ring face; recurve and
    /// barebow archers shoot the full 10-ring WA face.
    static func defaultFor(_ bowType: BowType) -> TargetFaceType {
        switch bowType {
        case .compound: return .sixRing
        case .recurve, .barebow: return .tenRing
        }
    }
}
