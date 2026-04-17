import Foundation

enum RearStabSide: String, Codable, CaseIterable {
    case none, left, right, both

    var label: String { rawValue.capitalized }
}

struct BowConfiguration: Identifiable, Codable, Equatable {
    var id: String
    var bowId: String
    var createdAt: Date
    var label: String?

    // Draw / letoff
    var drawLength: Double        // inches
    var letOffPct: Double         // %

    // String / cable
    var peepHeight: Double        // inches
    var dLoopLength: Double       // inches
    var topCableTwists: Int       // half-twists
    var bottomCableTwists: Int
    var mainStringTopTwists: Int
    var mainStringBottomTwists: Int

    // Limbs
    var topLimbTurns: Double      // half-turn increments, - = out
    var bottomLimbTurns: Double

    // Rest (sixteenth-inch increments)
    var restVertical: Int         // + = up
    var restHorizontal: Int       // + = right
    var restDepth: Double         // inches, + = forward

    // Sight / grip / nock
    var sightPosition: Int         // relative steps, 0 = baseline; + = back (extended), - = forward
    var gripAngle: Double         // degrees
    var nockingHeight: Int        // sixteenth-inch, + = up

    // Stabilizers
    var frontStabWeight: Double    // oz, 0 = none
    var frontStabAngle: Double     // degrees downward tilt, 0–10
    var rearStabSide: RearStabSide // none / left / right / both
    var rearStabWeight: Double     // oz (ignored when rearStabSide == .none)
    var rearStabVertAngle: Double  // degrees, -90 to +90
    var rearStabHorizAngle: Double // degrees, 0 to 90

    static func makeDefault(for bowId: String) -> BowConfiguration {
        BowConfiguration(
            id: UUID().uuidString,
            bowId: bowId,
            createdAt: Date(),
            label: "Initial Setup",
            drawLength: 28.0,
            letOffPct: 80,
            peepHeight: 9.0,
            dLoopLength: 2.0,
            topCableTwists: 0,
            bottomCableTwists: 0,
            mainStringTopTwists: 0,
            mainStringBottomTwists: 0,
            topLimbTurns: 0,
            bottomLimbTurns: 0,
            restVertical: 0,
            restHorizontal: 0,
            restDepth: 0,
            sightPosition: 0,
            gripAngle: 0,
            nockingHeight: 0,
            frontStabWeight: 0,
            frontStabAngle: 0,
            rearStabSide: .none,
            rearStabWeight: 0,
            rearStabVertAngle: 0,
            rearStabHorizAngle: 0
        )
    }
}
