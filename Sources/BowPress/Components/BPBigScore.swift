import SwiftUI

/// Hero numeric — splits on the decimal point. Integer and fractional parts
/// render in `appDeep` Fraunces non-italic (per spec the hero stat is
/// upright); the dot itself is `appMaple` (the one maple leaf).
/// Optional trailing `unit` renders in small Inter uppercase.
struct BPBigScore: View {
    let value: String
    let size: CGFloat
    let unit: String?

    init(value: String, size: CGFloat = 72, unit: String? = nil) {
        self.value = value
        self.size = size
        self.unit = unit
    }

    var body: some View {
        let parts = value.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts[0])
                .font(.bpDisplay(size, italic: false, weight: .medium))
                .foregroundStyle(Color.appDeep)
                .lineLimit(1)
            if parts.count == 2 {
                Text(".")
                    .font(.bpDisplay(size, italic: false, weight: .medium))
                    .foregroundStyle(Color.appMaple)
                    .lineLimit(1)
                Text(parts[1])
                    .font(.bpDisplay(size, italic: false, weight: .medium))
                    .foregroundStyle(Color.appDeep)
                    .lineLimit(1)
            }
            if let unit, !unit.isEmpty {
                Text(unit)
                    .font(.bpUI(max(11, size * 0.2), weight: .semibold))
                    .tracking(max(11, size * 0.2) * 0.12)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.appInk3)
                    .padding(.leading, 4)
                    .lineLimit(1)
            }
        }
        // Keep the split numerals on one line inside a narrow stat-grid column.
        // Without this, "10.3" wraps "10" → "1" + "0" on separate lines, and the
        // stray "0" rides below the maple-dot'd "1.3" looking like a dangling stat.
        .fixedSize(horizontal: true, vertical: false)
    }
}

#Preview {
    ZStack {
        Color.appPaper.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 20) {
            BPBigScore(value: "10.4")
            BPBigScore(value: "287", size: 64, unit: "pts")
            BPBigScore(value: "9.8", size: 56)
        }
        .padding()
    }
}
