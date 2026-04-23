import Foundation

enum RearStabSide: String, Codable, CaseIterable {
    case none, left, right, both

    var label: String { rawValue.capitalized }
}

// Fields marked optional below are type-specific (see backend `bowConfigController.ts`):
//   compound:         letOff, peep, dLoop, cable/limb twists, single rear-stab
//   recurve/barebow:  brace, tiller, plunger, (recurve only) clicker + V-bar L/R weights
struct BowConfiguration: Identifiable, Codable, Equatable {
    var id: String
    var bowId: String
    var createdAt: Date
    var label: String?

    // Draw / letoff
    var drawLength: Double                // shared, required
    var letOffPct: Double? = nil          // compound-only

    // String / cable
    var peepHeight: Double? = nil         // compound-only
    var dLoopLength: Double? = nil        // compound-only
    var topCableTwists: Int? = nil        // compound-only
    var bottomCableTwists: Int? = nil
    var mainStringTopTwists: Int? = nil
    var mainStringBottomTwists: Int? = nil

    // Limbs
    var topLimbTurns: Double? = nil       // compound-only
    var bottomLimbTurns: Double? = nil

    // Rest (sixteenth-inch increments)
    var restVertical: Int
    var restHorizontal: Int
    var restDepth: Double

    // Sight / grip / nock
    var sightPosition: Int? = nil         // compound / recurve (barebow nil)
    var gripAngle: Double
    var nockingHeight: Int

    // Front stabilizer (compound + recurve; barebow nil)
    var frontStabWeight: Double? = nil
    var frontStabAngle: Double? = nil

    // Compound single-rear-stab (nil on recurve/barebow — recurve uses V-bar L/R below)
    var rearStabSide: RearStabSide? = nil
    var rearStabWeight: Double? = nil
    var rearStabVertAngle: Double? = nil
    var rearStabHorizAngle: Double? = nil

    // Recurve-specific
    var braceHeight: Double? = nil        // inches
    var tillerTop: Double? = nil          // mm
    var tillerBottom: Double? = nil       // mm
    var plungerTension: Int? = nil        // integer clicks
    var clickerPosition: Double? = nil    // mm, recurve only (not barebow)
    var rearStabLeftWeight: Double? = nil // oz, V-bar left
    var rearStabRightWeight: Double? = nil// oz, V-bar right

    // Analytics fields populated by the server pipeline. iOS only reads these — they're
    // recomputed on each pipeline run and sent back on the next fetch. `isReference`
    // drives the "pinned" star in Equipment; `referenceManuallyPinned` tells the pipeline
    // to leave the pin alone instead of auto-updating on score changes.
    var isReference: Bool? = nil
    var referenceManuallyPinned: Bool? = nil
    var avgArrowScore: Double? = nil       // 0–100 composite (spec §Per-Configuration Score)
    var scoreable: Bool? = nil

    /// True when all tunable fields match, ignoring id, createdAt, and label.
    func hasMatchingValues(_ other: BowConfiguration) -> Bool {
        bowId == other.bowId &&
        drawLength == other.drawLength && letOffPct == other.letOffPct &&
        peepHeight == other.peepHeight && dLoopLength == other.dLoopLength &&
        topCableTwists == other.topCableTwists && bottomCableTwists == other.bottomCableTwists &&
        mainStringTopTwists == other.mainStringTopTwists && mainStringBottomTwists == other.mainStringBottomTwists &&
        topLimbTurns == other.topLimbTurns && bottomLimbTurns == other.bottomLimbTurns &&
        restVertical == other.restVertical && restHorizontal == other.restHorizontal && restDepth == other.restDepth &&
        sightPosition == other.sightPosition && gripAngle == other.gripAngle && nockingHeight == other.nockingHeight &&
        frontStabWeight == other.frontStabWeight && frontStabAngle == other.frontStabAngle &&
        rearStabSide == other.rearStabSide && rearStabWeight == other.rearStabWeight &&
        rearStabVertAngle == other.rearStabVertAngle && rearStabHorizAngle == other.rearStabHorizAngle &&
        braceHeight == other.braceHeight &&
        tillerTop == other.tillerTop && tillerBottom == other.tillerBottom &&
        plungerTension == other.plungerTension && clickerPosition == other.clickerPosition &&
        rearStabLeftWeight == other.rearStabLeftWeight && rearStabRightWeight == other.rearStabRightWeight
    }

    /// Convenience for preview/placeholder call sites that only have a bowId string.
    /// Produces a compound-style default; real flows should call `makeDefault(for: Bow)`.
    static func makeDefault(for bowId: String) -> BowConfiguration {
        let placeholder = Bow(
            id: bowId,
            userId: "",
            name: "",
            bowType: .compound,
            brand: "",
            model: "",
            createdAt: Date()
        )
        return makeDefault(for: placeholder)
    }

    static func makeDefault(for bow: Bow) -> BowConfiguration {
        switch bow.bowType {
        case .compound:
            return BowConfiguration(
                id: UUID().uuidString,
                bowId: bow.id,
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
                rearStabSide: RearStabSide.none,
                rearStabWeight: 0,
                rearStabVertAngle: 0,
                rearStabHorizAngle: 0
            )
        case .recurve:
            return BowConfiguration(
                id: UUID().uuidString,
                bowId: bow.id,
                createdAt: Date(),
                label: "Initial Setup",
                drawLength: 28.0,
                restVertical: 0,
                restHorizontal: 0,
                restDepth: 0,
                sightPosition: 0,
                gripAngle: 0,
                nockingHeight: 0,
                frontStabWeight: 6,
                frontStabAngle: 0,
                rearStabVertAngle: 0,
                rearStabHorizAngle: 0,
                braceHeight: 8.5,
                tillerTop: 0,
                tillerBottom: 0,
                plungerTension: 12,
                clickerPosition: 0,
                rearStabLeftWeight: 6,
                rearStabRightWeight: 6
            )
        case .barebow:
            return BowConfiguration(
                id: UUID().uuidString,
                bowId: bow.id,
                createdAt: Date(),
                label: "Initial Setup",
                drawLength: 28.0,
                restVertical: 0,
                restHorizontal: 0,
                restDepth: 0,
                gripAngle: 0,
                nockingHeight: 0,
                braceHeight: 8.5,
                tillerTop: 0,
                tillerBottom: 0,
                plungerTension: 12
            )
        }
    }
}

// MARK: - Display helpers

extension BowConfiguration {
    /// Compact one-line summary used for the "Base Setup" recap on edit screens.
    /// Shape depends on which optional fields this config actually has.
    /// e.g. `Draw 28.5" · Let-off 80% · Peep 9.25" · D-loop 2.125"` (compound imperial)
    /// e.g. `Draw 72.4 cm · Let-off 80% · Peep 23.5 cm · D-loop 5.4 cm`   (compound metric)
    func compactSetupLine(system: UnitSystem) -> String {
        var parts: [String] = [
            "Draw \(UnitFormatting.length(inches: drawLength, system: system))"
        ]
        if let letOff = letOffPct {
            parts.append("Let-off \(UnitFormatting.percent(letOff))")
        }
        if let peep = peepHeight {
            parts.append("Peep \(UnitFormatting.length(inches: peep, system: system))")
        }
        if let dLoop = dLoopLength {
            parts.append("D-loop \(UnitFormatting.length(inches: dLoop, system: system, digits: 3))")
        }
        if let brace = braceHeight {
            parts.append("Brace \(UnitFormatting.length(inches: brace, system: system, digits: 3))")
        }
        return parts.joined(separator: " · ")
    }
}
