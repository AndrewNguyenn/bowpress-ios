import SwiftUI

// MARK: - AnalyticsSuggestionsSection

struct AnalyticsSuggestionsSection: View {
    let suggestions: [AnalyticsSuggestion]
    var onMarkRead: ((AnalyticsSuggestion) async -> Void)? = nil

    private let limit = 8

    @State private var showAll: Bool = false

    private var visibleSuggestions: [AnalyticsSuggestion] {
        let sorted = suggestions.sorted { $0.confidence > $1.confidence }
        if showAll { return sorted }
        return Array(sorted.prefix(limit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Text("Tuning Suggestions")
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
                        SuggestionRow(suggestion: suggestion, onMarkRead: onMarkRead)
                            .onAppear {
                                if !suggestion.wasRead {
                                    Task { await onMarkRead?(suggestion) }
                                }
                            }
                    }
                }

                if suggestions.count > limit {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAll.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(showAll ? "Show less" : "Show more suggestions")
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
                Text("No tuning suggestions yet.")
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
}

// MARK: - SuggestionRow

private struct SuggestionRow: View {
    let suggestion: AnalyticsSuggestion
    var onMarkRead: ((AnalyticsSuggestion) async -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(alignment: .top, spacing: 10) {
                // Unread dot
                Circle()
                    .fill(suggestion.wasRead ? Color.clear : Color.appAccent)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(suggestion.parameter.bowParameterDisplayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        ConfidenceBadge(confidence: suggestion.confidence)
                    }

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

                    CompactConfidenceBar(confidence: suggestion.confidence)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(suggestion.reasoning)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
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
            .padding(.leading, 18)
        }
        .padding(14)
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
