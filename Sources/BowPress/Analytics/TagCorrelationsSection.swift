import SwiftUI

// Spec §Analysis Outputs #4 — Subjective-Objective Correlation.
// Renders per-feel-tag score correlations stored in `tag_correlations`.
// Each row is one tag: strength badge, tagged vs. untagged averages, delta.
struct TagCorrelationsSection: View {
    let bowId: String

    @State private var correlations: [TagCorrelation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Feel-to-Performance")
                .font(.headline)

            if isLoading && correlations.isEmpty {
                ProgressView()
            } else if correlations.isEmpty {
                Text("No correlations yet. Keep logging session feel tags — correlations appear once a tag has ≥3 tagged sessions and ≥15% score difference vs untagged.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(correlations) { row(for: $0) }
                }
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func row(for c: TagCorrelation) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    strengthBadge(c.strength)
                    Text(displayName(c.tag))
                        .font(.subheadline.weight(.semibold))
                }
                Text("\(c.taggedSessionCount) tagged · \(c.untaggedSessionCount) untagged")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if let delta = c.scoreDelta {
                let sign = delta >= 0 ? "+" : ""
                Text("\(sign)\(Int(delta.rounded())) pts")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(delta >= 0 ? .green : .red)
            }
        }
        .padding(10)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func strengthBadge(_ s: TagCorrelation.Strength) -> some View {
        Text(s.rawValue.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color(for: s))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color(for: s).opacity(0.15))
            .clipShape(Capsule())
    }

    private func color(for s: TagCorrelation.Strength) -> Color {
        switch s {
        case .weak: return .orange
        case .moderate: return .yellow
        case .strong: return .green
        }
    }

    // Humanise "sentiment:positive" → "Positive sentiment", "grip_torque" → "Grip torque"
    private func displayName(_ tag: String) -> String {
        if tag.hasPrefix("sentiment:") {
            let val = String(tag.dropFirst("sentiment:".count))
            return val.capitalized + " sentiment"
        }
        return tag
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            correlations = try await APIClient.shared.fetchTagCorrelations(bowId: bowId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
