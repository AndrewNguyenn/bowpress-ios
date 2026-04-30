import SwiftUI

// MARK: - Score Card Row
//
// Compact one-line score-card row used by both the active SessionView ends
// list and the historical SessionDetailSheet per-end breakdown. Density is
// tuned so 12 ends + header + footer fit in an iPhone screenshot.

struct ScoreCardRow: View {
    let endNumber: Int
    let arrows: [ArrowPlot]
    let runningTotal: Int
    var notes: String? = nil
    /// Optional tap handler for individual arrows. When nil, chips are not
    /// interactive (read-only contexts like history detail).
    var onArrowTap: ((String) -> Void)? = nil

    private var endTotal: Int { arrows.reduce(0) { $0 + min($1.ring, 10) } }
    private var xCount: Int { arrows.filter { $0.ring == 11 }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 6) {
                Text("\(endNumber)")
                    .font(.bpUI(11, weight: .semibold))
                    .foregroundStyle(Color.appInk3)
                    .frame(width: ScoreCardLayout.endColumn, alignment: .leading)

                arrowChips
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(endTotal)")
                    .font(.bpDisplay(15, italic: true, weight: .medium))
                    .foregroundStyle(Color.appPondDk)
                    .frame(width: ScoreCardLayout.totalColumn, alignment: .trailing)

                Text("\(xCount)X")
                    .font(.bpMono(10, weight: .medium))
                    .foregroundStyle(Color.appInk2)
                    .frame(width: ScoreCardLayout.xColumn, alignment: .trailing)

                Text("\(runningTotal)")
                    .font(.bpDisplay(15, italic: true, weight: .medium))
                    .foregroundStyle(Color.appInk)
                    .frame(width: ScoreCardLayout.runningColumn, alignment: .trailing)
            }
            if let notes, !notes.isEmpty {
                Text(notes)
                    .font(.bpDisplay(12, italic: true, weight: .regular))
                    .foregroundStyle(Color.appInk2)
                    .padding(.leading, 24)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            Rectangle().fill(Color.appLine).frame(height: 1),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private var arrowChips: some View {
        HStack(spacing: 2) {
            ForEach(arrows) { arrow in
                let isX = arrow.ring == 11
                let label = isX ? "X" : "\(arrow.ring)"
                let palette = ScoreCardRow.ringPalette(arrow.ring)
                let chip = Text(label)
                    .font(.bpDisplay(13, italic: true, weight: .medium))
                    .foregroundStyle(palette.text)
                    .frame(width: 22, height: 22)
                    .background(palette.fill)
                    .overlay(Rectangle().strokeBorder(palette.edge, lineWidth: 1))
                    .opacity(arrow.excluded ? 0.4 : 1.0)
                if let onArrowTap {
                    Button { onArrowTap(arrow.id) } label: { chip }
                        .buttonStyle(.plain)
                } else {
                    chip
                }
            }
        }
    }

    /// Kenrokuen-quiet variant: only the gold zone (X, 10, 9) gets a colored
    /// fill so the "bullseye" cue is preserved while the rest of the card stays
    /// in the paper palette. Everything else falls back to paper + ink.
    fileprivate struct RingPalette {
        let fill: Color
        let edge: Color
        let text: Color
    }

    fileprivate static func ringPalette(_ ring: Int) -> RingPalette {
        switch ring {
        case 11, 10, 9:
            return RingPalette(fill: .appWAGoldFill, edge: .appWAGoldEdge, text: .appInk)
        default:
            return RingPalette(fill: .appPaper, edge: .appLine, text: .appInk)
        }
    }
}

/// Shared column widths so header, rows, and footer stay in alignment.
fileprivate enum ScoreCardLayout {
    static let endColumn:     CGFloat = 24
    static let totalColumn:   CGFloat = 26
    static let xColumn:       CGFloat = 22
    static let runningColumn: CGFloat = 34
}

// MARK: - Score Card Header

struct ScoreCardHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("END")
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: ScoreCardLayout.endColumn, alignment: .leading)
            Text("ARROWS")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("TOT")
                .frame(width: ScoreCardLayout.totalColumn, alignment: .trailing)
            Text("X")
                .frame(width: ScoreCardLayout.xColumn, alignment: .trailing)
            Text("RT")
                .frame(width: ScoreCardLayout.runningColumn, alignment: .trailing)
        }
        .font(.bpUI(9, weight: .semibold))
        .appTracking(0.18, at: 9)
        .textCase(.uppercase)
        .foregroundStyle(Color.appInk3)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .overlay(
            Rectangle().fill(Color.appLine).frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Score Card Footer

struct ScoreCardFooter: View {
    let totalScore: Int
    let totalArrows: Int
    let totalXCount: Int

    private var maxPossible: Int { totalArrows * 10 }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("TOTAL")
                .font(.bpUI(9, weight: .semibold))
                .appTracking(0.18, at: 9)
                .textCase(.uppercase)
                .foregroundStyle(Color.appInk3)
            Spacer(minLength: 8)
            Text("\(totalXCount)X")
                .font(.bpMono(11, weight: .medium))
                .foregroundStyle(Color.appInk2)
            Text("\(totalScore)/\(maxPossible)")
                .font(.bpDisplay(17, italic: true, weight: .medium))
                .foregroundStyle(Color.appPondDk)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .overlay(
            Rectangle().fill(Color.appLine).frame(height: 1),
            alignment: .top
        )
    }
}
