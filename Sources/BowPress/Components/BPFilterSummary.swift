import SwiftUI

/// "Pill card" summary row — paper2 bg + 1px hairline + left summary/subtitle
/// and a right-aligned edit affordance.
struct BPFilterSummary: View {
    let summary: String
    let subtitle: String
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary)
                    .font(.bpDisplay(14, italic: true, weight: .medium))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.bpUI(10))
                    // 0.04em at 10pt
                    .tracking(10 * 0.04)
                    .foregroundStyle(Color.appInk3)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            BPEditLink(action: onEdit)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appPaper2)
        .overlay(Rectangle().strokeBorder(Color.appLine, lineWidth: 1))
    }
}

#Preview {
    ZStack {
        Color.appPaper.ignoresSafeArea()
        BPFilterSummary(
            summary: "50m · Hoyt compound · 110gr X10",
            subtitle: "Last 14 days · 312 arrows"
        ) { }
        .padding()
    }
}
