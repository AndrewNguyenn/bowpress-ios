import SwiftUI

/// Flat stamp — what replaces the capsule pill. Outlined, uppercase.
/// Tone sets the border + text color; `solid: true` fills the background.
struct BPStamp: View {
    enum Tone {
        case pond, pine, maple, stone, ink3

        var color: Color {
            switch self {
            case .pond:  return .appPondDk
            case .pine:  return .appPine
            case .maple: return .appMaple
            case .stone: return .appStone
            case .ink3:  return .appInk3
            }
        }
    }

    let text: String
    let tone: Tone
    let solid: Bool

    init(_ text: String, tone: Tone = .pond, solid: Bool = false) {
        self.text = text
        self.tone = tone
        self.solid = solid
    }

    var body: some View {
        let col = tone.color
        Text(text)
            .font(.bpUI(11, weight: .semibold))
            // CSS: letter-spacing 0.22em at 9pt = 9 * 0.22 = 1.98
            .tracking(9 * 0.22)
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(solid ? col : Color.clear)
            .foregroundStyle(solid ? Color.appPaper : col)
            .overlay(Rectangle().strokeBorder(col, lineWidth: 1))
    }
}

#Preview {
    ZStack {
        Color.appPaper.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 10) {
            BPStamp("Strong")
            BPStamp("Pine", tone: .pine)
            BPStamp("Flier", tone: .maple, solid: true)
            BPStamp("Neutral", tone: .stone)
            BPStamp("Weak", tone: .ink3)
        }
        .padding()
    }
}
