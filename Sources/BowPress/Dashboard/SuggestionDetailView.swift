import SwiftUI

struct SuggestionDetailView: View {
    let suggestion: AnalyticsSuggestion
    let viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    private var pct: Int { Int((suggestion.confidence * 100).rounded()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.parameter.bowParameterDisplayName)
                            .font(.largeTitle.weight(.bold))
                        DeliveryBadge(type: suggestion.deliveryType)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    // MARK: Suggested Change
                    DetailSection(title: "Suggested Change", systemImage: "arrow.left.arrow.right") {
                        HStack(spacing: 12) {
                            ValuePill(label: "Current", value: suggestion.currentValue, color: .secondary)
                            Image(systemName: "arrow.right")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            ValuePill(label: "Suggested", value: suggestion.suggestedValue, color: .accentColor)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // MARK: Confidence
                    DetailSection(title: "Confidence", systemImage: "chart.bar.fill") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(pct)%")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(confidenceColor)
                            ConfidenceBar(confidence: suggestion.confidence)
                        }
                    }

                    // MARK: Why
                    DetailSection(title: "Why", systemImage: "lightbulb.fill") {
                        Text(suggestion.reasoning)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // MARK: Qualifier (optional)
                    if let qualifier = suggestion.qualifier {
                        DetailSection(title: "Note", systemImage: "note.text") {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary)
                                Text(qualifier)
                                    .font(.callout)
                                    .italic()
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    Spacer(minLength: 24)

                    // MARK: Dismiss button
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            await viewModel.markRead(suggestion)
        }
    }

    private var confidenceColor: Color {
        switch suggestion.confidence {
        case 0.75...: return .green
        case 0.5...:  return .yellow
        default:      return .red
        }
    }
}

// MARK: - Supporting views

private struct DetailSection<Content: View>: View {
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

private struct ValuePill: View {
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

// MARK: - Preview

#Preview("With qualifier") {
    SuggestionDetailView(suggestion: .mockUnread, viewModel: DashboardViewModel())
}

#Preview("No qualifier") {
    SuggestionDetailView(suggestion: .mockRead, viewModel: DashboardViewModel())
}

#Preview("Reinforcement") {
    SuggestionDetailView(suggestion: .mockReinforcement, viewModel: DashboardViewModel())
}
