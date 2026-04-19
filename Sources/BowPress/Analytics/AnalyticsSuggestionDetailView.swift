import SwiftUI

// Detail screen pushed from the analytics tab when the user taps a suggestion
// row. Shows structured evidence the synthesizer captured + a primary
// "Apply to Bow" CTA that materializes the suggestion as a new immutable
// BowConfiguration snapshot.
//
// Pushed via `NavigationLink` from `AnalyticsSuggestionsSection`. The dashboard
// has its own AnalyticsSuggestionDetailView (presented as a sheet) — they share the
// `DetailSection` / `ValuePill` atoms but otherwise diverge in layout.
struct AnalyticsSuggestionDetailView: View {
    let suggestion: AnalyticsSuggestion
    var viewModel: AnalyticsViewModel?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var localSuggestion: AnalyticsSuggestion
    @State private var showApplyConfirm: Bool = false
    @State private var isApplying: Bool = false
    @State private var applyError: String?
    @State private var showSuccessBanner: Bool = false

    init(suggestion: AnalyticsSuggestion, viewModel: AnalyticsViewModel? = nil) {
        self.suggestion = suggestion
        self.viewModel = viewModel
        _localSuggestion = State(initialValue: suggestion)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // 1. Header
                header

                Divider()

                // 2. Why
                DetailSection(title: "Why", systemImage: "lightbulb.fill") {
                    Text(suggestion.reasoning)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    if let qualifier = suggestion.qualifier, !qualifier.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text(qualifier)
                                .font(.callout)
                                .italic()
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 4)
                    }
                }

                // 3. Evidence
                if let evidence = suggestion.evidence {
                    evidenceSection(evidence)
                }

                // 4. Bow context
                bowContextSection

                // 5. Apply CTA — disabled when already applied.
                applySection
            }
            .padding(20)
        }
        .navigationTitle(suggestion.parameter.bowParameterDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Apply this suggestion?", isPresented: $showApplyConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Apply") {
                Task { await performApply() }
            }
        } message: {
            Text("This will create a new configuration snapshot for this bow with \(suggestion.parameter.bowParameterDisplayName) set to \(suggestion.suggestedValue). You can revert from the Equipment tab.")
        }
        .alert(
            "Apply failed",
            isPresented: Binding(
                get: { applyError != nil },
                set: { if !$0 { applyError = nil } }
            ),
            presenting: applyError
        ) { _ in
            Button("OK", role: .cancel) { applyError = nil }
        } message: { msg in
            Text(msg)
        }
        .overlay(alignment: .top) {
            if showSuccessBanner {
                Text("Applied — new configuration created")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.green, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(suggestion.parameter.bowParameterDisplayName)
                    .font(.title2.weight(.bold))
                Spacer()
                ConfidenceBadge(confidence: suggestion.confidence)
            }
            HStack(spacing: 12) {
                ValuePill(label: "Current", value: suggestion.currentValue, color: .secondary)
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                ValuePill(label: "Suggested", value: suggestion.suggestedValue, color: .accentColor)
            }
            .frame(maxWidth: .infinity)
            if localSuggestion.wasApplied {
                appliedCapsule
            }
        }
    }

    private var appliedCapsule: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
            Text(appliedLabel)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.green, in: Capsule())
    }

    private var appliedLabel: String {
        if let date = localSuggestion.appliedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Applied \(formatter.string(from: date))"
        }
        return "Applied"
    }

    // MARK: - Evidence section

    private func evidenceSection(_ ev: SuggestionEvidence) -> some View {
        DetailSection(title: "Evidence", systemImage: "chart.bar.doc.horizontal") {
            VStack(alignment: .leading, spacing: 12) {
                Text(evidenceHeadline(ev))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    ForEach(Array(ev.metrics.enumerated()), id: \.offset) { _, metric in
                        HStack {
                            Text(metric.label).font(.subheadline)
                            Spacer()
                            Text(metric.value)
                                .font(.subheadline.weight(.semibold))
                            if let delta = metric.deltaFromBaseline, !delta.isEmpty {
                                Text(delta)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(deltaColor(delta))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(deltaColor(delta).opacity(0.15), in: Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }

                if !ev.sessionIds.isEmpty {
                    DisclosureGroup("Recent sessions (\(ev.sessionIds.count))") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(ev.sessionIds, id: \.self) { sid in
                                Text(sid)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 6)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func evidenceHeadline(_ ev: SuggestionEvidence) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let from = formatter.string(from: ev.windowStart)
        let to = formatter.string(from: ev.windowEnd)
        return "Based on \(ev.sampleSize) arrows across \(ev.sessionIds.count) sessions, \(from) – \(to)."
    }

    private func deltaColor(_ delta: String) -> Color {
        if delta.hasPrefix("+") { return .green }
        if delta.hasPrefix("-") { return .red }
        return .secondary
    }

    // MARK: - Bow context

    private var bowContextSection: some View {
        let bow = appState.bows.first(where: { $0.id == suggestion.bowId })
        let configLabel = appState.bowConfigs[suggestion.bowId]?.label ?? "Latest configuration"
        return DetailSection(title: "Bow", systemImage: "scope") {
            VStack(alignment: .leading, spacing: 4) {
                Text(bow?.name ?? "Unknown bow")
                    .font(.body.weight(.semibold))
                Text("Modifying: \(configLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Apply

    private var applySection: some View {
        VStack(spacing: 12) {
            if localSuggestion.wasApplied {
                Button {
                    // Read-only success state — nothing to do beyond returning.
                    dismiss()
                } label: {
                    Text(applyButtonLabel)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.gray.opacity(0.25))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(true)
            } else {
                Button {
                    showApplyConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        if isApplying {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        }
                        Text(isApplying ? "Applying…" : "Apply to Bow")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isApplying || viewModel == nil)
            }
        }
        .padding(.top, 12)
    }

    private var applyButtonLabel: String {
        if let date = localSuggestion.appliedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Applied \(formatter.string(from: date)) — view new config"
        }
        return "Applied — view new config"
    }

    @MainActor
    private func performApply() async {
        guard let viewModel else { return }
        isApplying = true
        defer { isApplying = false }
        do {
            _ = try await viewModel.apply(suggestion)
            // Reflect the now-applied state locally so the CTA flips and the
            // capsule appears without re-entering.
            if let updated = viewModel.suggestions.first(where: { $0.id == suggestion.id }) {
                localSuggestion = updated
            } else {
                localSuggestion.wasApplied = true
                localSuggestion.appliedAt = Date()
            }
            withAnimation(.easeInOut(duration: 0.3)) { showSuccessBanner = true }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeInOut(duration: 0.3)) { showSuccessBanner = false }
            try? await Task.sleep(nanoseconds: 200_000_000)
            dismiss()
        } catch {
            applyError = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview("Pending — with evidence") {
    NavigationStack {
        AnalyticsSuggestionDetailView(suggestion: AnalyticsSuggestion.previewWithEvidence)
    }
    .environment(AppState())
}

#Preview("Already applied") {
    NavigationStack {
        AnalyticsSuggestionDetailView(suggestion: AnalyticsSuggestion.previewApplied)
    }
    .environment(AppState())
}

extension AnalyticsSuggestion {
    static var previewWithEvidence: AnalyticsSuggestion {
        AnalyticsSuggestion(
            id: "preview-1",
            bowId: "dev_bow1",
            createdAt: Date().addingTimeInterval(-3600),
            parameter: "restVertical",
            suggestedValue: "+3/16\"",
            currentValue: "+2/16\"",
            reasoning: "Vertical impact bias detected across last 3 sessions.",
            confidence: 0.82,
            qualifier: "Re-verify after 2 sessions.",
            wasRead: true,
            wasDismissed: false,
            deliveryType: .push,
            evidence: SuggestionEvidence(
                sampleSize: 47,
                sessionIds: ["dev_s1_6", "dev_s1_7", "dev_s1_8"],
                windowStart: Date().addingTimeInterval(-86_400 * 14),
                windowEnd: Date(),
                metrics: [
                    .init(label: "Average score", value: "10.5", deltaFromBaseline: "+0.4"),
                    .init(label: "Vertical drift", value: "0.09 in", deltaFromBaseline: "+0.06 in"),
                ],
                relatedConfigChangeIds: nil,
                patternType: "directional_drift"
            )
        )
    }

    static var previewApplied: AnalyticsSuggestion {
        AnalyticsSuggestion(
            id: "preview-applied",
            bowId: "dev_bow1",
            createdAt: Date().addingTimeInterval(-3600 * 24 * 3),
            parameter: "peepHeight",
            suggestedValue: "9.5\"",
            currentValue: "9.25\"",
            reasoning: "Anchor inconsistency mitigated.",
            confidence: 0.71,
            qualifier: nil,
            wasRead: true,
            wasDismissed: false,
            deliveryType: .inApp,
            evidence: nil,
            wasApplied: true,
            appliedAt: Date().addingTimeInterval(-3600 * 18),
            appliedConfigId: "preview-applied-cfg"
        )
    }
}
