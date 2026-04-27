import SwiftUI

/// Numbered suggestion/trend row. Layout: 22pt index / flex body / auto-width
/// stamp. An optional `accessory` slot is reserved for confidence bars, etc.
struct BPLedgerRow: View {
    let index: Int
    let title: String
    let detail: String?
    let monoLine: String?
    let stamp: String?
    let stampTone: BPStamp.Tone
    let accessory: AnyView?

    init(
        index: Int,
        title: String,
        detail: String? = nil,
        monoLine: String? = nil,
        stamp: String? = nil,
        stampTone: BPStamp.Tone = .pond,
        accessory: AnyView? = nil
    ) {
        self.index = index
        self.title = title
        self.detail = detail
        self.monoLine = monoLine
        self.stamp = stamp
        self.stampTone = stampTone
        self.accessory = accessory
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index)")
                .font(.bpDisplay(24, italic: true, weight: .medium))
                .foregroundStyle(Color.appPond)
                .frame(width: 22, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.bpDisplay(21, italic: true, weight: .medium))
                    .foregroundStyle(Color.appInk)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.bpUI(14))
                        .foregroundStyle(Color.appInk2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let monoLine {
                    Text(monoLine)
                        .font(.bpMono(11.5))
                        // 0.06em at 9.5pt
                        .tracking(9.5 * 0.06)
                        .foregroundStyle(Color.appInk3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let accessory {
                    accessory
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let stamp {
                BPStamp(stamp, tone: stampTone)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ZStack {
        Color.appPaper.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 0) {
            BPLedgerRow(
                index: 1,
                title: "Shorten draw length by 0.25\"",
                detail: "Group pattern suggests over-drawn release.",
                monoLine: "confidence 0.72 · last 48 arrows",
                stamp: "Strong",
                stampTone: .pond
            )
            Rectangle().fill(Color.appLine2).frame(height: 1)
            BPLedgerRow(
                index: 2,
                title: "Check nock fit",
                detail: nil,
                monoLine: "confidence 0.41",
                stamp: "Flier",
                stampTone: .maple
            )
        }
        .padding()
    }
}
