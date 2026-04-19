import SwiftUI

// Shared atoms used by both the dashboard's existing SuggestionDetailView and
// the new analytics-tab SuggestionDetailView. Lifted out of
// Dashboard/SuggestionDetailView.swift so the two screens can present a
// consistent visual vocabulary without copy-paste drift.
//
// These were `private` on the dashboard view; now they're internal so both
// detail views can compose them directly.

struct DetailSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

struct ValuePill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.1))
                )
        }
    }
}
