import SwiftUI

// MARK: - AnalyticsSuggestionsSection

struct AnalyticsSuggestionsSection: View {
    let suggestions: [AnalyticsSuggestion]
    var onMarkRead: ((AnalyticsSuggestion) async -> Void)? = nil

    private let initialLimit = 5

    @State private var showAll: Bool = false
    @State private var expandedIds: Set<String> = []

    private var visibleSuggestions: [AnalyticsSuggestion] {
        let sorted = suggestions.sorted {
            if $0.wasRead != $1.wasRead { return !$0.wasRead }
            return $0.confidence > $1.confidence
        }
        if showAll { return sorted }
        return Array(sorted.prefix(initialLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Section header
            HStack {
                Text("Insights & Suggestions")
                    .font(.headline)
                if !suggestions.isEmpty {
                    Text("\(suggestions.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.appAccent, in: Capsule())
                }
                Spacer()
            }

            if suggestions.isEmpty {
                emptySuggestionsView
            } else {
                VStack(spacing: 10) {
                    ForEach(visibleSuggestions) { suggestion in
                        SuggestionRow(
                            suggestion: suggestion,
                            isExpanded: expandedIds.contains(suggestion.id),
                            onTap: { toggleExpanded(suggestion) },
                            onMarkRead: onMarkRead
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: visibleSuggestions.map(\.id))

                if suggestions.count > initialLimit {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAll.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(showAll ? "Show less" : "Show all \(suggestions.count)")
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: showAll ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.appAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.appAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptySuggestionsView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(.quaternary)
                Text("No suggestions for this period.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Keep logging sessions.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }

    private func toggleExpanded(_ suggestion: AnalyticsSuggestion) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedIds.contains(suggestion.id) {
                expandedIds.remove(suggestion.id)
            } else {
                expandedIds.insert(suggestion.id)
                // Mark as read when expanded
                if !suggestion.wasRead {
                    Task { await onMarkRead?(suggestion) }
                }
            }
        }
    }
}

// MARK: - SuggestionRow

private struct SuggestionRow: View {
    let suggestion: AnalyticsSuggestion
    let isExpanded: Bool
    let onTap: () -> Void
    var onMarkRead: ((AnalyticsSuggestion) async -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Compact header (always visible)
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 10) {
                    // Unread dot
                    Circle()
                        .fill(suggestion.wasRead ? Color.clear : Color.appAccent)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 6) {
                        // Parameter name + confidence badge
                        HStack(alignment: .firstTextBaseline) {
                            Text(suggestion.parameter.bowParameterDisplayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            ConfidenceBadge(confidence: suggestion.confidence)
                        }

                        // Suggested change summary
                        HStack(spacing: 4) {
                            Text(suggestion.currentValue)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(suggestion.suggestedValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appAccent)
                        }

                        // Confidence bar
                        CompactConfidenceBar(confidence: suggestion.confidence)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                        .padding(.horizontal, 14)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(suggestion.reasoning)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let qualifier = suggestion.qualifier {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text(qualifier)
                                    .font(.caption)
                                    .italic()
                                    .foregroundStyle(.tertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appSurface)
                .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    suggestion.wasRead ? Color.clear : Color.appAccent.opacity(0.35),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - ConfidenceBadge

struct ConfidenceBadge: View {
    let confidence: Double

    private var label: String {
        switch confidence {
        case 0.7...: return "High"
        case 0.4..<0.7: return "Medium"
        default: return "Low"
        }
    }

    private var color: Color {
        switch confidence {
        case 0.7...: return Color.appAccent
        case 0.4..<0.7: return .orange
        default: return .gray
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }
}

// MARK: - CompactConfidenceBar

private struct CompactConfidenceBar: View {
    let confidence: Double

    private var color: Color {
        switch confidence {
        case 0.7...: return Color.appAccent
        case 0.4..<0.7: return .orange
        default: return .gray
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemFill)).frame(height: 5)
                Capsule().fill(color).frame(width: geo.size.width * confidence, height: 5)
            }
        }
        .frame(height: 5)
    }
}

// MARK: - Previews

#Preview("With suggestions") {
    ScrollView {
        AnalyticsSuggestionsSection(suggestions: AnalyticsSuggestion.mockAllSuggestions)
            .padding()
    }
    .background(Color.appBackground)
}

#Preview("Empty") {
    ScrollView {
        AnalyticsSuggestionsSection(suggestions: [])
            .padding()
    }
    .background(Color.appBackground)
}

#Preview("Many suggestions (show-all button)") {
    let extra1 = AnalyticsSuggestion(id: "s14", bowId: "b1", createdAt: Date().addingTimeInterval(-14400), parameter: "peepHeight", suggestedValue: "9.25\"", currentValue: "9.0\"", reasoning: "Peep height analysis.", confidence: 0.4, qualifier: nil, wasRead: false, deliveryType: .inApp)
    let extra2 = AnalyticsSuggestion(id: "s15", bowId: "b1", createdAt: Date().addingTimeInterval(-18000), parameter: "dLoopLength", suggestedValue: "2.125\"", currentValue: "2.0\"", reasoning: "D-loop data shows pattern.", confidence: 0.55, qualifier: "Check with press.", wasRead: true, deliveryType: .push)
    let extra3 = AnalyticsSuggestion(id: "s16", bowId: "b1", createdAt: Date().addingTimeInterval(-21600), parameter: "sightPosition", suggestedValue: "+1", currentValue: "0", reasoning: "Sight distance correlation found.", confidence: 0.35, qualifier: nil, wasRead: false, deliveryType: .reinforcement)
    ScrollView {
        AnalyticsSuggestionsSection(suggestions: AnalyticsSuggestion.mockAllSuggestions + [extra1, extra2, extra3])
            .padding()
    }
    .background(Color.appBackground)
}
