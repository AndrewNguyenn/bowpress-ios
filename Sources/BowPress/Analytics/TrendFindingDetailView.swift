import SwiftUI

// Detail screen pushed when the user taps a row in the Trend analysis ledger.
// Mirrors the row's Kenrokuen typography (Fraunces / Inter / JetBrains Mono)
// and expands the same fields with breathing room: the body paragraph runs
// roomier, the cues line splits into a list, and a short explainer keyed to
// the badge tells the archer what Watch / Gain / Hold actually mean.
//
// Pushed via `NavigationLink` from `AnalyticsView.trendAnalysis()`. No CTA,
// no mutations — purely informational.

struct TrendFindingDetailView: View {
    let finding: TrendFinding

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Rectangle().fill(Color.appLine).frame(height: 1)
                bodyParagraph
                badgeExplainer
                if let cues = finding.cues, !cues.isEmpty {
                    cuesBreakdown(cues)
                }
                footnote
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
        .background(Color.appPaper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(roman(finding.index)) · finding")
                    .font(.bpDisplay(13, italic: true, weight: .medium))
                    .foregroundStyle(Color.appPond)
                    .tracking(13 * 0.02)

                Text(finding.title)
                    .font(.bpDisplay(22, italic: true, weight: .medium))
                    .foregroundStyle(Color.appInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text(finding.metric.text)
                    .font(.bpMono(13, weight: .medium))
                    .foregroundStyle(metricTone)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            BPStamp(finding.badge.label, tone: finding.badge.stampTone)
                .padding(.top, 4)
        }
    }

    private var metricTone: Color {
        switch finding.metric.tone {
        case .positive: return .appPine
        case .negative: return .appMaple
        case .neutral:  return .appPondDk
        }
    }

    // MARK: - Body paragraph

    private var bodyParagraph: some View {
        Text(finding.body)
            .font(.bpUI(13.5))
            .foregroundStyle(Color.appInk2)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Badge explainer

    private var badgeExplainer: some View {
        VStack(alignment: .leading, spacing: 8) {
            BPEyebrow("WHAT THIS MEANS", tone: badgeEyebrowTone)
            Text(badgeExplainerCopy)
                .font(.bpUI(12.5))
                .foregroundStyle(Color.appInk2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var badgeEyebrowTone: BPEyebrow.Tone {
        switch finding.badge {
        case .gain:  return .pine
        case .watch: return .maple
        case .hold:  return .ink3
        }
    }

    private var badgeExplainerCopy: String {
        switch finding.badge {
        case .gain:
            return "A Gain finding flags something working well. Hold the current setup and use this to understand what's contributing to the result so you can replicate it."
        case .watch:
            return "A Watch finding flags an emerging pattern worth acting on before it sets. The cues below are the most common levers — start with the bolded ones."
        case .hold:
            return "A Hold finding doesn't have enough signal yet. Keep shooting; the trend will either firm up or fade with more sessions."
        }
    }

    // MARK: - Cues breakdown

    @ViewBuilder
    private func cuesBreakdown(_ raw: String) -> some View {
        let parts = raw.components(separatedBy: " · ")
        if let header = parts.first {
            VStack(alignment: .leading, spacing: 10) {
                BPEyebrow(header.uppercased())
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(parts.dropFirst().enumerated()), id: \.offset) { _, segment in
                        cueRow(segment)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cueRow(_ raw: String) -> some View {
        let segments = parseBold(raw)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(Color.appPond)
                .frame(width: 4, height: 4)
                .padding(.top, 5)
            segments.reduce(Text("")) { acc, seg in
                acc + Text(seg.text)
                    .font(.bpMono(11.5, weight: seg.bold ? .medium : .regular))
                    .foregroundStyle(seg.bold ? Color.appInk : Color.appInk2)
            }
            .tracking(11.5 * 0.02)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Footnote

    private var footnote: some View {
        Text("finding #\(finding.index) · ranked by actionability")
            .font(.bpUI(10))
            .foregroundStyle(Color.appInk3)
            .padding(.top, 6)
    }

    // MARK: - Helpers

    private struct Seg { let text: String; let bold: Bool }

    private func parseBold(_ s: String) -> [Seg] {
        var out: [Seg] = []
        var remaining = Substring(s)
        while let range = remaining.range(of: "**") {
            let lead = remaining[..<range.lowerBound]
            if !lead.isEmpty { out.append(Seg(text: String(lead), bold: false)) }
            let afterOpen = remaining[range.upperBound...]
            if let close = afterOpen.range(of: "**") {
                let boldPart = afterOpen[..<close.lowerBound]
                out.append(Seg(text: String(boldPart), bold: true))
                remaining = afterOpen[close.upperBound...]
            } else {
                out.append(Seg(text: String(afterOpen), bold: false))
                return out
            }
        }
        if !remaining.isEmpty { out.append(Seg(text: String(remaining), bold: false)) }
        return out
    }

    private func roman(_ n: Int) -> String {
        let table = ["", "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x", "xi", "xii"]
        if n >= 0 && n < table.count { return table[n] + "." }
        return "\(n)."
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Watch — drifting high") {
    NavigationStack {
        TrendFindingDetailView(finding: MockAnalyticsWave2.trends(period: .week).findings[0])
    }
}

#Preview("Gain — X-ring") {
    NavigationStack {
        TrendFindingDetailView(finding: MockAnalyticsWave2.trends(period: .week).findings[2])
    }
}

#Preview("Hold — tuning change") {
    NavigationStack {
        TrendFindingDetailView(finding: MockAnalyticsWave2.trends(period: .week).findings[4])
    }
}
#endif
