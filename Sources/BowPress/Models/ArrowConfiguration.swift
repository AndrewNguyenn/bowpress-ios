import Foundation

struct ArrowConfiguration: Identifiable, Codable, Equatable {
    var id: String
    var userId: String
    var label: String
    var brand: String?
    var model: String?
    var length: Double            // inches
    var pointWeight: Int          // grains
    var fletchingType: FletchingType
    var fletchingLength: Double   // inches
    var fletchingOffset: Double   // degrees
    var nockType: String?
    var totalWeight: Int?         // grains
    var shaftDiameter: ShaftDiameter?
    var notes: String?

    enum FletchingType: String, Codable, CaseIterable {
        case vane, feather
    }

    enum ShaftDiameter: Double, Codable, CaseIterable {
        case mm3_2   = 3.2
        case mm4_0   = 4.0
        case mm5_0   = 5.0
        case in19_64 = 7.540625   // 19/64"
        case in21_64 = 8.334375   // 21/64"
        case in22_64 = 8.731250   // 22/64"
        case in23_64 = 9.128125   // 23/64"
        case in24_64 = 9.525000   // 24/64"
        case in25_64 = 9.921875   // 25/64"
        case in26_64 = 10.318750  // 26/64"
        case in27_64 = 10.715625  // 27/64"

        func displayName(for system: UnitSystem) -> String {
            switch system {
            case .metric:
                // Every case is storable as millimetres via its raw value.
                let mm = rawValue
                let formatted = mm == mm.rounded() ? String(format: "%.0f", mm) : String(format: "%.1f", mm)
                return "\(formatted) mm"
            case .imperial:
                switch self {
                case .mm3_2, .mm4_0, .mm5_0:
                    // No clean 64ths fraction; show decimal inches.
                    let inches = rawValue / UnitConversion.inchToMm
                    return String(format: "%.3f\"", inches)
                case .in19_64: return "19/64\""
                case .in21_64: return "21/64\""
                case .in22_64: return "22/64\""
                case .in23_64: return "23/64\""
                case .in24_64: return "24/64\""
                case .in25_64: return "25/64\""
                case .in26_64: return "26/64\""
                case .in27_64: return "27/64\""
                }
            }
        }
    }
}

// MARK: - Display helpers

extension ArrowConfiguration {
    /// One-line arrow spec used in Session and Log surfaces.
    /// e.g. `28.5" · 110gr · vane` (imperial) or `72.4 cm · 7.1g · vane` (metric).
    func specSummary(system: UnitSystem) -> String {
        let len = UnitFormatting.length(inches: length, system: system)
        let mass = UnitFormatting.arrowMass(grains: pointWeight, system: system)
        return "\(len) · \(mass) · \(fletchingType.rawValue)"
    }
}
