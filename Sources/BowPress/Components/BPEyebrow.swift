import SwiftUI

/// Micro-label — Inter 9pt semibold, 0.22em tracking, uppercase.
/// Tone defaults to ink3 (tertiary).
struct BPEyebrow: View {
    enum Tone {
        case pond, maple, pine, ink3

        var color: Color {
            switch self {
            case .pond:  return .appPondDk
            case .maple: return .appMaple
            case .pine:  return .appPine
            case .ink3:  return .appInk3
            }
        }
    }

    let text: String
    let tone: Tone

    init(_ text: String, tone: Tone = .ink3) {
        self.text = text
        self.tone = tone
    }

    var body: some View {
        Text(text)
            .font(.bpEyebrow(11))
            // 0.22em at 9pt
            .tracking(9 * 0.22)
            .textCase(.uppercase)
            .foregroundStyle(tone.color)
    }
}

#Preview {
    ZStack {
        Color.appPaper.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 8) {
            BPEyebrow("This morning")
            BPEyebrow("Pond", tone: .pond)
            BPEyebrow("Maple alert", tone: .maple)
        }
        .padding()
    }
}
