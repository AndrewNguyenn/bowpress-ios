import SwiftUI

/// Delta chip — mono, tiny, positive/negative/flat.
/// JetBrains Mono 10pt, 1×5 padding, 2pt radius (tiny enough to read as
/// "barely perceptible" per the radius scale).
struct BPDelta: View {
    let value: Double
    let suffix: String

    init(value: Double, suffix: String = "") {
        self.value = value
        self.suffix = suffix
    }

    private var text: String {
        if value > 0 {
            return "+\(format(value))\(suffix)"
        } else if value < 0 {
            return "\(format(value))\(suffix)"
        } else {
            return "\u{2014}" // em-dash
        }
    }

    private var fg: Color {
        if value > 0 { return .appPine }
        if value < 0 { return .appMaple }
        return .appInk3
    }

    private var bg: Color {
        if value > 0 { return Color.appPine.opacity(0.16) }
        if value < 0 { return Color.appMaple.opacity(0.12) }
        return Color.clear
    }

    private func format(_ v: Double) -> String {
        // Strip trailing zeros, keep up to one decimal.
        let rounded = (v * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded)
    }

    var body: some View {
        Text(text)
            .font(.bpMono(10))
            // 0.04em at 10pt
            .tracking(10 * 0.04)
            .foregroundStyle(fg)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

#Preview {
    ZStack {
        Color.appPaper.ignoresSafeArea()
        HStack(spacing: 8) {
            BPDelta(value: 1.3)
            BPDelta(value: -2.1)
            BPDelta(value: 0)
            BPDelta(value: 5, suffix: "pp")
        }
        .padding()
    }
}
