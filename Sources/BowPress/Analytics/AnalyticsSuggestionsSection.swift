import SwiftUI

// MARK: - AnalyticsSuggestionsSection

struct AnalyticsSuggestionsSection: View {
    let suggestions: [AnalyticsSuggestion]
    var highlightedId: String? = nil
    var onMarkRead: ((AnalyticsSuggestion) async -> Void)? = nil
    var onDismiss: ((AnalyticsSuggestion) async -> Void)? = nil
    /// Optional view-model handle so the row can push a detail view that
    /// has the apply-action handle. When nil (previews), tapping a row
    /// still navigates but the apply CTA is disabled in the detail view.
    var viewModel: AnalyticsViewModel? = nil

    private let limit = 8

    @State private var showAll: Bool = false
    @State private var pendingDismiss: AnalyticsSuggestion?

    var visibleSuggestions: [AnalyticsSuggestion] {
        // Push applied suggestions to the bottom — they're an audit trail,
        // not actionable. Within each bucket, keep highest-confidence first.
        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.wasApplied != rhs.wasApplied {
                return !lhs.wasApplied // pending (false) before applied (true)
            }
            return lhs.confidence > rhs.confidence
        }
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
                        NavigationLink {
                            AnalyticsSuggestionDetailView(suggestion: suggestion, viewModel: viewModel)
                        } label: {
                            SwipeableSuggestionRow(
                                suggestion: suggestion,
                                canDismiss: onDismiss != nil,
                                onMarkRead: onMarkRead,
                                onRequestDismiss: { pendingDismiss = $0 }
                            )
                        }
                        .buttonStyle(.plain)
                        .id(suggestion.id)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.appAccent, lineWidth: 3)
                                .opacity(suggestion.id == highlightedId ? 1 : 0)
                                .animation(.easeInOut(duration: 0.4), value: highlightedId)
                        )
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
        .alert(
            "Dismiss suggestion?",
            isPresented: Binding(
                get: { pendingDismiss != nil },
                set: { if !$0 { pendingDismiss = nil } }
            ),
            presenting: pendingDismiss
        ) { suggestion in
            Button("Cancel", role: .cancel) { pendingDismiss = nil }
            Button("Dismiss", role: .destructive) {
                let s = suggestion
                pendingDismiss = nil
                Task { await onDismiss?(s) }
            }
        } message: { _ in
            Text("This suggestion won't appear again unless the underlying pattern re-fires after 3 more sessions.")
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

// MARK: - SwipeableSuggestionRow

/// Wraps `SuggestionRow` with a left-swipe-to-reveal trash action. We can't use
/// the system `.swipeActions` modifier here because the suggestions list lives in
/// a `VStack` inside a `ScrollView`, not a `List`. A full swipe past the threshold
/// triggers the dismiss confirmation directly, mirroring iOS Mail behavior.
private struct SwipeableSuggestionRow: View {
    let suggestion: AnalyticsSuggestion
    let canDismiss: Bool
    var onMarkRead: ((AnalyticsSuggestion) async -> Void)?
    let onRequestDismiss: (AnalyticsSuggestion) -> Void

    @State private var offset: CGFloat = 0
    @State private var restingOffset: CGFloat = 0

    private let actionWidth: CGFloat = 80
    private let fullSwipeThreshold: CGFloat = 140

    var body: some View {
        ZStack(alignment: .trailing) {
            if canDismiss {
                trashAction
                    .opacity(offset < -1 ? 1 : 0)
            }

            SuggestionRow(suggestion: suggestion, onMarkRead: onMarkRead)
                .offset(x: offset)
                .gesture(canDismiss ? swipeGesture : nil)
        }
    }

    private var trashAction: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                offset = 0
                restingOffset = 0
            }
            onRequestDismiss(suggestion)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.red)
                Image(systemName: "trash.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: actionWidth)
            .frame(maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss suggestion")
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                // Ignore predominantly-vertical drags so the parent ScrollView wins.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let proposed = restingOffset + value.translation.width
                offset = proposed < 0 ? proposed : proposed / 5  // rubberband when pulled right
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.width - value.translation.width
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    if offset < -fullSwipeThreshold || (velocity < -300 && offset < -actionWidth / 2) {
                        offset = 0
                        restingOffset = 0
                        onRequestDismiss(suggestion)
                    } else if offset < -actionWidth / 2 {
                        offset = -actionWidth
                        restingOffset = -actionWidth
                    } else {
                        offset = 0
                        restingOffset = 0
                    }
                }
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
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(suggestion.parameter.bowParameterDisplayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if suggestion.wasApplied {
                            // Audit-trail badge — applied rows stay visible
                            // (sorted to bottom by visibleSuggestions) so the
                            // archer can see what's been adopted.
                            Text("Applied")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green, in: Capsule())
                        }
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
