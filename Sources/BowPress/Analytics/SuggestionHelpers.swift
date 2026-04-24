import SwiftUI

// MARK: - Parameter display-name mapping
//
// Preserved from the deleted Dashboard/SuggestionCard.swift — still consumed by
// AnalyticsSuggestionDetailView + the new Analytics ledger rows.

extension String {
    /// Converts a camelCase bow-config parameter key to a human-readable title.
    var bowParameterDisplayName: String {
        let map: [String: String] = [
            "drawLength":             "Draw Length",
            "letOffPct":              "Let-Off %",
            "peepHeight":             "Peep Height",
            "dLoopLength":            "D-Loop Length",
            "topCableTwists":         "Top Cable Twists",
            "bottomCableTwists":      "Bottom Cable Twists",
            "mainStringTopTwists":    "Main String Top Twists",
            "mainStringBottomTwists": "Main String Bottom Twists",
            "topLimbTurns":           "Top Limb Turns",
            "bottomLimbTurns":        "Bottom Limb Turns",
            "restVertical":           "Rest Vertical",
            "restHorizontal":         "Rest Horizontal",
            "restDepth":              "Rest Depth",
            "sightPosition":          "Sight Position",
            "gripAngle":              "Grip Angle",
            "nockingHeight":          "Nocking Height",
        ]
        if let display = map[self] { return display }
        // Fallback: split camelCase on uppercase boundaries
        let spaced = unicodeScalars.reduce("") { result, scalar in
            if CharacterSet.uppercaseLetters.contains(scalar) && !result.isEmpty {
                return result + " " + String(scalar)
            }
            return result + String(scalar)
        }
        return spaced.capitalized
    }
}

// MARK: - Relative-date formatter

let bpRelativeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .short
    return f
}()

// MARK: - Mock fixtures kept alive for SwiftUI #Preview

extension AnalyticsSuggestion {
    static let mockUnread = AnalyticsSuggestion(
        id: "s1",
        bowId: "b1",
        createdAt: Date().addingTimeInterval(-7_200),
        parameter: "nockingHeight",
        suggestedValue: "+3/16\"",
        currentValue: "0\"",
        reasoning: "Arrow impact groups high at 20 yards. Raising the nocking point by 3/16\" should bring the vertical centre-of-impact back in line.",
        confidence: 0.87,
        qualifier: "Based on 12 sessions over 30 days.",
        wasRead: false,
        deliveryType: .push
    )

    static let mockRead = AnalyticsSuggestion(
        id: "s2",
        bowId: "b1",
        createdAt: Date().addingTimeInterval(-86_400),
        parameter: "drawLength",
        suggestedValue: "28.5\"",
        currentValue: "29\"",
        reasoning: "String-slap and elbow over-rotation markers consistent with a 1/2\" too-long draw.",
        confidence: 0.72,
        qualifier: nil,
        wasRead: true,
        deliveryType: .inApp
    )

    static let mockReinforcement = AnalyticsSuggestion(
        id: "s3",
        bowId: "b2",
        createdAt: Date().addingTimeInterval(-3_600 * 48),
        parameter: "restVertical",
        suggestedValue: "No change needed",
        currentValue: "13/16\"",
        reasoning: "Rest vertical position stable across the last 8 sessions; correlates with best grouping.",
        confidence: 0.94,
        qualifier: nil,
        wasRead: false,
        deliveryType: .reinforcement
    )

    static let mockAllSuggestions: [AnalyticsSuggestion] = [
        .mockUnread,
        .mockRead,
        .mockReinforcement,
        AnalyticsSuggestion(
            id: "s4",
            bowId: "b2",
            createdAt: Date().addingTimeInterval(-3_600 * 72),
            parameter: "topLimbTurns",
            suggestedValue: "+0.5 turns",
            currentValue: "3 turns",
            reasoning: "Chrono data shows velocity variance of ±4 fps — adding half a limb turn tightens the power stroke.",
            confidence: 0.61,
            qualifier: "Verify with a draw scale before adjusting.",
            wasRead: true,
            deliveryType: .inApp
        ),
    ]
}

// MARK: - Inline summary + stamp mapping for the ledger rows

extension AnalyticsSuggestion {
    /// Short inline summary for `BPLedgerRow.detail`. If the server supplies
    /// `inlineSummary` directly we use that; otherwise we synthesize a
    /// `current → suggested` hint so the row still reads sensibly.
    var resolvedInlineSummary: String {
        if let override = inlineSummary, !override.isEmpty { return override }
        let cur = currentValue.trimmingCharacters(in: .whitespaces)
        let next = suggestedValue.trimmingCharacters(in: .whitespaces)
        if cur.isEmpty { return next }
        if next.isEmpty { return cur }
        return "\(cur) \u{2192} \(next)"
    }

    /// Badge text rendered in the ledger row's stamp.
    var resolvedStatusStamp: String {
        if let override = statusStamp, !override.isEmpty { return override }
        if wasApplied { return "Applied" }
        if confidence >= 0.85 { return "Good" }
        if confidence < 0.6 { return "Review" }
        return "Proposed"
    }

    /// Tone for `BPStamp` based on the resolved stamp text.
    var resolvedStampTone: BPStamp.Tone {
        switch resolvedStatusStamp.lowercased() {
        case "new", "proposed", "applied":
            return .pond
        case "good":
            return .pine
        case "review", "dismissed":
            return .maple
        default:
            return .pond
        }
    }
}
