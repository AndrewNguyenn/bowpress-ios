import SwiftUI

/// Secondary button — 1px hairline rectangle, uppercase Inter 11pt label.
/// Tintable via `tone`; default pondDk.
struct BPHairlineButton: View {
    enum Tone {
        case pondDk, maple, pine

        var color: Color {
            switch self {
            case .pondDk: return .appPondDk
            case .maple:  return .appMaple
            case .pine:   return .appPine
            }
        }
    }

    let title: String
    let tone: Tone
    let action: () -> Void

    init(_ title: String, tone: Tone = .pondDk, action: @escaping () -> Void) {
        self.title = title
        self.tone = tone
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.bpUI(11, weight: .semibold))
                // 0.18em at 11pt
                .tracking(11 * 0.18)
                .textCase(.uppercase)
                .foregroundStyle(tone.color)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 14)
                .overlay(Rectangle().strokeBorder(Color.appLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.appPaper.ignoresSafeArea()
        VStack(spacing: 14) {
            BPHairlineButton("View details") { }
            BPHairlineButton("Discard", tone: .maple) { }
        }
        .padding()
    }
}
