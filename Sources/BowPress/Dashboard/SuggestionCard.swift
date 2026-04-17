import SwiftUI

// MARK: - Parameter display-name mapping

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
            "sightPosition":            "Sight Position",
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

// MARK: - Delivery type helpers

extension AnalyticsSuggestion.DeliveryType {
    var label: String {
        switch self {
        case .push:         return "Push"
        case .inApp:        return "In App"
        case .reinforcement: return "Positive"
        }
    }

    var color: Color {
        switch self {
        case .push:         return .orange
        case .inApp:        return .appAccentAlt
        case .reinforcement: return .appAccent
        }
    }
}

// MARK: - Relative date formatter

private let relativeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .full
    return f
}()

// MARK: - SuggestionCard

struct SuggestionCard: View {
    let suggestion: AnalyticsSuggestion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Unread indicator
            Circle()
                .fill(suggestion.wasRead ? Color.clear : Color.appAccent)
                .frame(width: 10, height: 10)
                .padding(.top, 5)
                .animation(.easeInOut(duration: 0.3), value: suggestion.wasRead)

            VStack(alignment: .leading, spacing: 8) {
                // Top row: parameter name + delivery badge
                HStack {
                    Text(suggestion.parameter.bowParameterDisplayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    DeliveryBadge(type: suggestion.deliveryType)
                }

                // Suggested change
                HStack(spacing: 4) {
                    Text("Change from")
                        .foregroundStyle(.secondary)
                    Text(suggestion.currentValue)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(suggestion.suggestedValue)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appAccent)
                }
                .font(.subheadline)

                // Confidence bar
                ConfidenceBar(confidence: suggestion.confidence)

                // Timestamp
                Text(relativeFormatter.localizedString(for: suggestion.createdAt, relativeTo: .now))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appSurface)
                .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 3)
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

// MARK: - Sub-views

struct ConfidenceBar: View {
    let confidence: Double

    private var pct: Int { Int((confidence * 100).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemFill))
                        .frame(height: 6)
                    Capsule()
                        .fill(confidenceColor)
                        .frame(width: geo.size.width * confidence, height: 6)
                }
            }
            .frame(height: 6)
            Text("\(pct)% confidence")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var confidenceColor: Color {
        switch confidence {
        case 0.75...: return .appAccent
        case 0.5...:  return .yellow
        default:      return .red
        }
    }
}

struct DeliveryBadge: View {
    let type: AnalyticsSuggestion.DeliveryType

    var body: some View {
        Text(type.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(type.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(type.color.opacity(0.15))
            )
    }
}

// MARK: - Preview

#Preview("Unread push suggestion") {
    List {
        SuggestionCard(suggestion: .mockUnread)
        SuggestionCard(suggestion: .mockRead)
        SuggestionCard(suggestion: .mockReinforcement)
    }
    .listStyle(.plain)
}

// MARK: - Mock data (shared across previews)

extension AnalyticsSuggestion {
    static let mockUnread = AnalyticsSuggestion(
        id: "s1",
        bowId: "b1",
        createdAt: Date().addingTimeInterval(-7_200),
        parameter: "nockingHeight",
        suggestedValue: "+3/16\"",
        currentValue: "0\"",
        reasoning: "Your arrow impact is consistently grouping high at 20 yards. Raising the nocking point by 3/16\" should bring the vertical center-of-impact inline with your sight pin.",
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
        reasoning: "Form analysis indicates consistent string-slap and elbow over-rotation, which are classic markers of a draw length that is 1/2\" too long.",
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
        reasoning: "Rest vertical position has been stable across the last 8 sessions and correlates with your best grouping scores. Keep it here.",
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
            reasoning: "Chrono data shows velocity variance of ±4 fps which is above acceptable range. Adding half a limb turn increases poundage and tightens the power stroke.",
            confidence: 0.61,
            qualifier: "Verify with a draw scale before making adjustments.",
            wasRead: true,
            deliveryType: .inApp
        ),
    ]
}
