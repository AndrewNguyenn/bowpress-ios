import SwiftUI

// Spec §Analysis Outputs #3 — Change Impact Cards.
// Renders one card per ConfigurationChange with score delta, classification,
// and aggregated feel tags on each side. Data source: the analytics pipeline's
// Stage 4 (computeChangeImpact) which writes `impact` onto each
// ConfigurationChange row. Changes without an `impact` field (not yet scored)
// render a muted "pending" row instead of being hidden.
struct ChangeImpactCardsSection: View {
    let bowId: String

    @State private var changes: [ConfigurationChange] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Change Impact")
                .font(.headline)

            if isLoading && changes.isEmpty {
                ProgressView()
            } else if changes.isEmpty {
                Text("No config changes yet. Tuning adjustments will appear here with before/after scores.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(changes) { change in
                        card(for: change)
                    }
                }
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func card(for change: ConfigurationChange) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(summaryTitle(change))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                classificationBadge(change)
            }

            if let impact = change.impact {
                deltaRow(impact)
                if !impact.feelTagsAfter.isEmpty || !impact.feelTagsBefore.isEmpty {
                    feelTagsRow(impact)
                }
            } else {
                Text("Pending analytics — needs ≥6 arrows under this config for impact scoring.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let notes = change.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption).italic()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func summaryTitle(_ c: ConfigurationChange) -> String {
        if c.changedFields.isEmpty { return "Configuration change" }
        let shown = c.changedFields.prefix(2)
            .map { "\($0.field): \($0.fromValue) → \($0.toValue)" }
            .joined(separator: "  ·  ")
        return c.changedFields.count > 2
            ? "\(shown)  +\(c.changedFields.count - 2) more"
            : shown
    }

    @ViewBuilder
    private func classificationBadge(_ c: ConfigurationChange) -> some View {
        if let impact = c.impact {
            Text(impact.classification.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(impact.classification == .clean ? Color.green : .orange)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background((impact.classification == .clean ? Color.green : .orange).opacity(0.15))
                .clipShape(Capsule())
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func deltaRow(_ impact: ChangeImpactCard) -> some View {
        HStack(spacing: 16) {
            if let before = impact.scoreBefore {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BEFORE").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
                    Text("\(Int(before))").font(.title3.weight(.semibold))
                }
            }
            Image(systemName: "arrow.right")
                .foregroundStyle(.tertiary)
            if let after = impact.scoreAfter {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AFTER").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
                    Text("\(Int(after))").font(.title3.weight(.semibold))
                }
            }
            Spacer()
            if let delta = impact.scoreDelta {
                let sign = delta >= 0 ? "+" : ""
                Text("\(sign)\(Int(delta)) pts")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(delta >= 0 ? .green : .red)
            }
        }
    }

    @ViewBuilder
    private func feelTagsRow(_ impact: ChangeImpactCard) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if !impact.feelTagsBefore.isEmpty {
                Text("Before: \(impact.feelTagsBefore.prefix(3).joined(separator: " · "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !impact.feelTagsAfter.isEmpty {
                Text("After: \(impact.feelTagsAfter.prefix(3).joined(separator: " · "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            changes = try await APIClient.shared.fetchConfigurationChanges(bowId: bowId)
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
