import Foundation

/// Frozen snapshot of the data the analytics pipeline saw when it produced
/// the suggestion. Optional because suggestions persisted before migration
/// 0015 don't carry one — clients must tolerate `nil` and degrade to the
/// reasoning text alone.
struct SuggestionEvidence: Codable, Equatable {
    var sampleSize: Int
    var sessionIds: [String]
    var windowStart: Date
    var windowEnd: Date
    var metrics: [Metric]
    var relatedConfigChangeIds: [String]?
    var patternType: String

    struct Metric: Codable, Equatable {
        var label: String
        var value: String
        var deltaFromBaseline: String?
    }
}

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
    // Migration 0015 — frozen snapshot of pipeline inputs at synthesis time.
    var evidence: SuggestionEvidence?
    var wasApplied: Bool = false
    var appliedAt: Date?
    var appliedConfigId: String?

    enum DeliveryType: String, Codable {
        case push, inApp, reinforcement
    }

    enum CodingKeys: String, CodingKey {
        case id, bowId, createdAt, parameter, suggestedValue, currentValue
        case reasoning, confidence, qualifier, wasRead, wasDismissed, deliveryType
        case evidence, wasApplied, appliedAt, appliedConfigId
    }

    init(
        id: String, bowId: String, createdAt: Date, parameter: String,
        suggestedValue: String, currentValue: String, reasoning: String,
        confidence: Double, qualifier: String? = nil, wasRead: Bool,
        wasDismissed: Bool = false, deliveryType: DeliveryType,
        evidence: SuggestionEvidence? = nil,
        wasApplied: Bool = false,
        appliedAt: Date? = nil,
        appliedConfigId: String? = nil
    ) {
        self.id = id; self.bowId = bowId; self.createdAt = createdAt
        self.parameter = parameter; self.suggestedValue = suggestedValue
        self.currentValue = currentValue; self.reasoning = reasoning
        self.confidence = confidence; self.qualifier = qualifier
        self.wasRead = wasRead; self.wasDismissed = wasDismissed
        self.deliveryType = deliveryType
        self.evidence = evidence
        self.wasApplied = wasApplied
        self.appliedAt = appliedAt
        self.appliedConfigId = appliedConfigId
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
        // All Migration-0015 fields default-tolerantly: older API responses
        // (pre-0015 or third-party) decode without exploding.
        evidence = try c.decodeIfPresent(SuggestionEvidence.self, forKey: .evidence)
        wasApplied = try c.decodeIfPresent(Bool.self, forKey: .wasApplied) ?? false
        appliedAt = try c.decodeIfPresent(Date.self, forKey: .appliedAt)
        appliedConfigId = try c.decodeIfPresent(String.self, forKey: .appliedConfigId)
    }

    // MARK: - Mock-only helpers
    //
    // The DEBUG mock branch of APIClient.applySuggestion needs a tiny
    // string→number parser and a way to write that number into a typed
    // BowConfiguration field. These helpers stay attached here (rather
    // than buried in DevMockData) so the parser logic for camelCase
    // parameter names is colocated with the Suggestion type.

    #if DEBUG
    static func parsedNumber(from raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        // Try fraction "<int>?(<num>/<den>)" — handles "+3/16\"".
        let fractionPattern = #"^([+-]?)(\d+)?\s*(\d+)\s*/\s*(\d+)"#
        if let regex = try? NSRegularExpression(pattern: fractionPattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
        {
            func slice(_ idx: Int) -> String? {
                guard let r = Range(match.range(at: idx), in: trimmed) else { return nil }
                return String(trimmed[r])
            }
            let sign = slice(1) ?? ""
            let whole = slice(2).flatMap { Double($0) } ?? 0
            if let num = slice(3).flatMap({ Double($0) }), let den = slice(4).flatMap({ Double($0) }), den != 0 {
                let value = whole + num / den
                return sign == "-" ? -value : value
            }
        }
        // Plain leading number: "+1", "9.5", "0.5 turns", "11"
        let scanner = Scanner(string: trimmed)
        scanner.charactersToBeSkipped = nil
        var d: Double = 0
        if scanner.scanDouble(&d) { return d }
        return nil
    }

    static func applyMockValue(_ value: Double, to config: inout BowConfiguration, parameter: String) {
        switch parameter {
        case "drawLength": config.drawLength = value
        case "letOffPct": config.letOffPct = value
        case "peepHeight": config.peepHeight = value
        case "dLoopLength": config.dLoopLength = value
        case "topCableTwists": config.topCableTwists = Int(value.rounded())
        case "bottomCableTwists": config.bottomCableTwists = Int(value.rounded())
        case "mainStringTopTwists": config.mainStringTopTwists = Int(value.rounded())
        case "mainStringBottomTwists": config.mainStringBottomTwists = Int(value.rounded())
        case "topLimbTurns": config.topLimbTurns = value
        case "bottomLimbTurns": config.bottomLimbTurns = value
        case "restVertical": config.restVertical = Int(value.rounded())
        case "restHorizontal": config.restHorizontal = Int(value.rounded())
        case "restDepth": config.restDepth = value
        case "sightPosition": config.sightPosition = Int(value.rounded())
        case "gripAngle": config.gripAngle = value
        case "nockingHeight": config.nockingHeight = Int(value.rounded())
        case "frontStabWeight": config.frontStabWeight = value
        case "frontStabAngle": config.frontStabAngle = value
        case "rearStabWeight": config.rearStabWeight = value
        case "rearStabVertAngle": config.rearStabVertAngle = value
        case "rearStabHorizAngle": config.rearStabHorizAngle = value
        case "braceHeight": config.braceHeight = value
        case "tillerTop": config.tillerTop = value
        case "tillerBottom": config.tillerBottom = value
        case "plungerTension": config.plungerTension = Int(value.rounded())
        case "clickerPosition": config.clickerPosition = value
        case "rearStabLeftWeight": config.rearStabLeftWeight = value
        case "rearStabRightWeight": config.rearStabRightWeight = value
        default: break
        }
    }
    #endif
}
